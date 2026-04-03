from __future__ import annotations

import json
import logging
import time
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.llm_models import (
    gemini_completion_model_id,
    is_gemini_route,
    is_openai_route,
    openai_completion_model_id,
    supports_vision_route,
)
from app.core.deps import get_current_user, get_db
from app.models.attachment import Attachment
from app.models.chat_message import ChatMessage
from app.models.chat_session import ChatSession
from app.models.usage_event import UsageEvent
from app.models.user import User
from app.schemas.chat import ChatSendRequest, ChatSendResponse, MessageOut, SourceItem, attachment_ids_from_column
from app.services.attachments.storage import get_storage_driver
from app.services.llm.deepseek_client import DeepSeekClient
from app.services.llm.gemini_client import GeminiClient
from app.services.llm.openai_client import OpenAIClient
from app.services.runtime_settings import (
    effective_deepseek_config,
    effective_gemini_config,
    effective_openai_config,
)
from app.services.llm.prompts import BRAVE_REALTIME_SYNTHESIS_RULES, SYSTEM_PROMPT
from app.services.chat.session_title import derive_conversation_title
from app.services.attachments.public_links import sign_attachment_id
from app.services.realtime.brave_provider import BraveFetchOutcome
from app.services.realtime.realtime_response_service import execute_brave_realtime, response_sources_from_outcome
from app.services.realtime.realtime_router import route_user_query
from app.services.conversation_coaching import turn_coaching_system_blocks
from app.services.intelligence.classify import resolve_task_type
from app.services.intelligence.context_trimmer import trim_chat_history_messages
from app.services.intelligence.model_router import vision_warnings
from app.services.intelligence.output_validator import append_source_footer, validate_assistant_output
from app.services.intelligence.prompt_builder import build_system_prompt
from app.services.intelligence.search_format import format_structured_search_block
from app.services.intelligence.search_policy import should_trigger_search
from app.services.intelligence.task_types import TaskType


router = APIRouter()
logger = logging.getLogger(__name__)


def _external_base_url(request: Request) -> str:
    """生成外网可访问 base url（优先 PUBLIC_BASE_URL；否则用反代透传的 Host/Proto）。"""
    env_base = (settings.public_base_url or "").strip().rstrip("/")
    if env_base and ("127.0.0.1" not in env_base) and ("localhost" not in env_base):
        return env_base

    proto = (request.headers.get("x-forwarded-proto") or request.url.scheme or "http").split(",")[0].strip()
    host = (request.headers.get("x-forwarded-host") or request.headers.get("host") or "").split(",")[0].strip()
    if host:
        return f"{proto}://{host}".rstrip("/")

    return env_base or str(request.base_url).strip().rstrip("/")


def _err(code: str, message: str, http_status: int) -> HTTPException:
    return HTTPException(status_code=http_status, detail={"error": {"code": code, "message": message, "details": {}}})


def _sources_from_list(raw: list[dict]) -> list[SourceItem]:
    items: list[SourceItem] = []
    for r in raw:
        try:
            if r.get("url"):
                items.append(
                    SourceItem(
                        title=str(r.get("title") or ""),
                        url=str(r["url"]),
                        snippet=str(r.get("snippet") or ""),
                        provider=str(r.get("provider") or "brave"),
                        type=str(r.get("type") or "web"),
                    )
                )
        except Exception:
            continue
    return items


@router.post("/messages", response_model=ChatSendResponse)
async def send_message(
    req: ChatSendRequest,
    request: Request,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ChatSendResponse:
    request_id = str(uuid.uuid4())
    t0 = time.perf_counter()
    warnings: list[str] = []
    validator_flags: list[str] = []

    session = (
        db.query(ChatSession)
        .filter(ChatSession.id == req.session_id, ChatSession.user_id == user.id, ChatSession.deleted_at.is_(None))
        .one_or_none()
    )
    if not session:
        raise _err("NOT_FOUND", "Session not found", status.HTTP_404_NOT_FOUND)

    model = req.model
    web_requested = bool(req.web_search_enabled)

    attachments = (
        db.query(Attachment)
        .filter(Attachment.session_id == session.id, Attachment.user_id == user.id, Attachment.deleted_at.is_(None), Attachment.status == "active")
        .order_by(Attachment.created_at.asc())
        .all()
    )
    image_attachments = [a for a in attachments if a.content_type in ("image/jpeg", "image/png", "image/webp")]
    req_attachment_ids = [str(x).strip() for x in (req.attachment_ids or []) if str(x).strip()]
    if len(req_attachment_ids) > 16:
        raise _err("VALIDATION_ERROR", "单次消息关联附件过多", status.HTTP_422_UNPROCESSABLE_ENTITY)
    active_att_ids = {str(a.id) for a in attachments}
    for aid in req_attachment_ids:
        if aid not in active_att_ids:
            raise _err("VALIDATION_ERROR", "附件不属于当前会话或已删除", status.HTTP_422_UNPROCESSABLE_ENTITY)

    text = (req.text or "").strip()
    if not text and not attachments:
        raise _err("VALIDATION_ERROR", "请输入内容或添加附件", status.HTTP_422_UNPROCESSABLE_ENTITY)

    att_text_blob = "\n".join((a.extracted_text or "") for a in attachments if a.extracted_text)
    task_type, classify_reason = await resolve_task_type(
        text=text or "（用户未输入文字，请结合附件与图片判断任务。）",
        has_image_attachment=bool(image_attachments),
        attachment_extracted_text=att_text_blob,
        db=db,
    )

    warnings.extend(vision_warnings(model=model, has_image=bool(image_attachments)))
    if image_attachments and not supports_vision_route(model):
        msg = (
            "DeepSeek 第一版不支持图片附件问答，请切换到 ChatGPT 或 Gemini"
            if model == "deepseek"
            else "当前所选模型不支持图片附件。"
        )
        raise _err("VALIDATION_ERROR", msg, status.HTTP_422_UNPROCESSABLE_ENTITY)

    history_limit = min(50, max(4, settings.max_context_turns * 2))
    history = (
        db.query(ChatMessage)
        .filter(ChatMessage.session_id == session.id, ChatMessage.deleted_at.is_(None))
        .order_by(ChatMessage.created_at.asc())
        .limit(history_limit)
        .all()
    )

    route = route_user_query(text)
    run_brave = False
    if user.can_web_search:
        if settings.feature_search_auto_trigger:
            run_brave = should_trigger_search(task_type, text, web_requested) or route.needs_realtime
        else:
            run_brave = web_requested and route.needs_realtime
    else:
        if task_type == TaskType.SEARCH_REQUIRED or route.needs_realtime:
            warnings.append("当前问题可能涉及时效信息，但账号未开通联网检索权限，将仅用模型知识回答。")

    if not settings.feature_search_auto_trigger and route.needs_realtime and not web_requested:
        raise _err(
            "REALTIME_REQUIRES_WEB_SEARCH",
            "这句话看起来需要**最新或实时**的客观信息。请先在输入区开启「联网搜索（实时）」后再发送，或改写去掉强时效表述。",
            status.HTTP_422_UNPROCESSABLE_ENTITY,
        )

    if settings.feature_search_auto_trigger and task_type == TaskType.CREATIVE_WRITE:
        run_brave = False

    system_core = (
        build_system_prompt(
            task_type,
            attachment_summaries=[f"文件名：{a.filename}，类型：{a.content_type}，约 {a.size_bytes} 字节" for a in attachments],
        )
        if settings.feature_structured_prompts
        else SYSTEM_PROMPT
    )

    llm_messages: list[dict] = [{"role": "system", "content": system_core}]
    for m in history:
        llm_messages.append({"role": m.role, "content": m.content_text})

    trimmed = False
    if settings.feature_context_compression:
        llm_messages, trimmed = trim_chat_history_messages(llm_messages, max_history_tokens=settings.context_history_token_budget)
        if trimmed:
            warnings.append("对话历史较长，已自动裁剪较早轮次以控制长度。")
            validator_flags.append("context_trimmed")

    attachment_context_parts: list[str] = []
    for a in attachments:
        if a.extracted_text:
            attachment_context_parts.append(f"[附件:{a.filename}]\n{a.extracted_text}\n")
    if attachment_context_parts:
        llm_messages.append({"role": "system", "content": "以下为本会话附件提取文本，仅供参考：\n" + "\n".join(attachment_context_parts)})

    for block in turn_coaching_system_blocks(
        text=text,
        has_attachments=bool(attachments),
        has_image_attachments=bool(image_attachments),
        vision_model_in_use=bool(supports_vision_route(model) and image_attachments),
    ):
        llm_messages.append({"role": "system", "content": block})

    brave_out: BraveFetchOutcome | None = None
    sources: list[dict] = []
    realtime_meta: dict | None = None

    if run_brave:
        brave_out = await execute_brave_realtime(db, user_query=text)
        sources = response_sources_from_outcome(brave_out)
        realtime_meta = {
            "provider": "brave",
            "status": brave_out.status,
            "message": brave_out.message,
            "queried_at": brave_out.queried_at_iso,
            "classify_reason": route.classify_reason,
            "task_type": task_type.value,
            "classify_path": classify_reason,
        }
        if brave_out.status == "ok" and brave_out.context_block.strip():
            if settings.feature_search_structured_injection:
                inj = format_structured_search_block(
                    queried_at=brave_out.queried_at_iso,
                    sources=sources,
                    context_block=brave_out.context_block,
                )
                llm_messages.append({"role": "system", "content": f"{BRAVE_REALTIME_SYNTHESIS_RULES}\n\n{inj}"})
            else:
                llm_messages.append({"role": "system", "content": f"{BRAVE_REALTIME_SYNTHESIS_RULES}\n\n{brave_out.context_block}"})
        elif brave_out.status != "ok":
            llm_messages.append(
                {
                    "role": "system",
                    "content": (
                        f"联网检索未能完成（状态：{brave_out.status}）。说明：{brave_out.message}\n"
                        "请仍尽力协助用户：可给可操作的建议、基于常识的框架、如何自行核实最新信息；"
                        "不得虚构检索结果或具体实时数字；涉及强时效事实须明确标注不确定，并建议用户稍后重试联网。"
                    ),
                }
            )
            warnings.append("实时搜索暂时不可用或结果不理想，已改为基于模型知识回答。")

    prior_user_count = sum(1 for m in history if m.role == "user")
    if prior_user_count == 0:
        session.title = derive_conversation_title(text) if text else "图片对话"
        db.add(session)

    if supports_vision_route(model) and image_attachments:
        storage = get_storage_driver()
        prompt_text = text or "请描述并分析这张图片。"
        blocks: list[dict] = [{"type": "text", "text": prompt_text}]
        for a in image_attachments:
            try:
                url = storage.presign_get(bucket=a.storage_bucket, object_path=a.storage_path, expires_seconds=10 * 60)
            except Exception:
                url = ""

            if url and (url.startswith("https://") or url.startswith("http://")):
                blocks.append({"type": "image_url", "image_url": {"url": url}})
                continue

            base = _external_base_url(request)
            t = sign_attachment_id(str(a.id))
            fallback = f"{base}/api/attachments/public/{a.id}?token={t}"
            blocks.append({"type": "image_url", "image_url": {"url": fallback}})
        llm_messages.append({"role": "user", "content": blocks})
    else:
        llm_messages.append({"role": "user", "content": text})

    effective_web = (web_requested and user.can_web_search) or bool(run_brave and brave_out)

    user_msg = ChatMessage(
        session_id=session.id,
        user_id=user.id,
        role="user",
        content_text=text,
        model=model,
        web_search_enabled=effective_web,
        sources_json=[],
        realtime_meta=None,
        attachment_ids=req_attachment_ids if req_attachment_ids else None,
        deleted_at=None,
    )
    db.add(user_msg)
    db.flush()

    assistant_text = ""
    try:
        if is_openai_route(model):
            ocfg = effective_openai_config(db)
            client = OpenAIClient(api_key=ocfg.api_key, base_url=ocfg.base_url, proxy=ocfg.proxy)
            use_model = settings.openai_model_vision if image_attachments else openai_completion_model_id(model)
            resp = await client.chat(messages=llm_messages, model=use_model)
            assistant_text = resp.text
        elif is_gemini_route(model):
            gcfg = effective_gemini_config(db)
            client = GeminiClient(api_key=gcfg.api_key, base_url=gcfg.base_url, proxy=gcfg.proxy)
            use_model = gemini_completion_model_id(model)
            resp = await client.chat(messages=llm_messages, model=use_model)
            assistant_text = resp.text
        else:
            dcfg = effective_deepseek_config(db)
            client = DeepSeekClient(api_key=dcfg.api_key, base_url=dcfg.base_url, proxy=dcfg.proxy)
            resp = await client.chat_text(messages=llm_messages, model=dcfg.model)
            assistant_text = resp.text
    except Exception as e:
        logger.exception("LLM call failed (model=%s, has_images=%s)", model, bool(image_attachments))
        db.rollback()
        raise _err("INTERNAL_ERROR", f"模型调用失败：{e}", status.HTTP_500_INTERNAL_SERVER_ERROR)

    assistant_sources = sources if (run_brave and brave_out and brave_out.status == "ok") else []

    if settings.feature_output_validation:
        assistant_text, vflags = validate_assistant_output(assistant_text)
        validator_flags.extend(vflags)
    if assistant_sources:
        assistant_text = append_source_footer(content=assistant_text, sources=assistant_sources)

    assistant_msg = ChatMessage(
        session_id=session.id,
        user_id=user.id,
        role="assistant",
        content_text=assistant_text,
        model=model,
        web_search_enabled=effective_web,
        sources_json=assistant_sources,
        realtime_meta=realtime_meta,
        deleted_at=None,
    )
    db.add(assistant_msg)

    user.chat_message_count += 1
    db.add(user)
    db.add(
        UsageEvent(
            user_id=user.id,
            session_id=session.id,
            event_type="chat",
            meta_json={
                "model": model,
                "web_search_enabled": effective_web,
                "realtime": route.needs_realtime,
                "brave_status": brave_out.status if brave_out else None,
                "task_type": task_type.value,
                "classify_reason": classify_reason,
                "search_run": bool(run_brave),
                "validator_flags": validator_flags,
            },
        )
    )

    db.commit()
    db.refresh(user_msg)
    db.refresh(assistant_msg)
    db.refresh(session)

    latency_ms = int((time.perf_counter() - t0) * 1000)
    log_payload = {
        "log_level": "INFO",
        "request_id": request_id,
        "session_id": str(session.id),
        "model": model,
        "task_type": task_type.value,
        "search_triggered": bool(run_brave),
        "classify_reason": classify_reason,
        "latency_total_ms": latency_ms,
        "validator_flags": validator_flags,
    }
    logger.info("%s", json.dumps(log_payload, ensure_ascii=False))

    return ChatSendResponse(
        user_message=MessageOut(
            id=str(user_msg.id),
            role=user_msg.role,
            content_text=user_msg.content_text,
            model=user_msg.model,
            web_search_enabled=bool(user_msg.web_search_enabled),
            sources=[],
            created_at=user_msg.created_at.isoformat(),
            realtime_meta=None,
            attachment_ids=attachment_ids_from_column(user_msg.attachment_ids),
        ),
        assistant_message=MessageOut(
            id=str(assistant_msg.id),
            role=assistant_msg.role,
            content_text=assistant_msg.content_text,
            model=assistant_msg.model,
            web_search_enabled=bool(assistant_msg.web_search_enabled),
            sources=_sources_from_list(assistant_sources),
            created_at=assistant_msg.created_at.isoformat(),
            realtime_meta=assistant_msg.realtime_meta if isinstance(assistant_msg.realtime_meta, dict) else None,
            attachment_ids=[],
        ),
        session_title=session.title or "",
        task_type=task_type.value,
        warnings=warnings,
        intelligence={
            "request_id": request_id,
            "classify_reason": classify_reason,
            "latency_ms": latency_ms,
            "validator_flags": validator_flags,
            "context_trimmed": trimmed if settings.feature_context_compression else False,
        },
    )
