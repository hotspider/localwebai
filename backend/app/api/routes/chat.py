from __future__ import annotations

from datetime import datetime
import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.llm_models import is_openai_route, openai_completion_model_id
from app.core.deps import get_current_user, get_db
from app.models.attachment import Attachment
from app.models.chat_message import ChatMessage
from app.models.chat_session import ChatSession
from app.models.usage_event import UsageEvent
from app.models.user import User
from app.schemas.chat import ChatSendRequest, ChatSendResponse, MessageOut, SourceItem
from app.services.attachments.storage import get_storage_driver
from app.services.llm.deepseek_client import DeepSeekClient
from app.services.llm.openai_client import OpenAIClient
from app.services.runtime_settings import effective_deepseek_config, effective_openai_config
from app.services.llm.prompts import SYSTEM_PROMPT
from app.services.chat.session_title import derive_conversation_title
from app.services.search.web_search import web_search
from app.services.attachments.public_links import sign_attachment_id


router = APIRouter()
logger = logging.getLogger(__name__)


def _err(code: str, message: str, http_status: int) -> HTTPException:
    return HTTPException(status_code=http_status, detail={"error": {"code": code, "message": message, "details": {}}})


def _sources_from_list(raw: list[dict]) -> list[SourceItem]:
    items: list[SourceItem] = []
    for r in raw:
        try:
            if r.get("url"):
                items.append(SourceItem(**r))
        except Exception:
            continue
    return items


@router.post("/messages", response_model=ChatSendResponse)
async def send_message(
    req: ChatSendRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ChatSendResponse:
    session = (
        db.query(ChatSession)
        .filter(ChatSession.id == req.session_id, ChatSession.user_id == user.id, ChatSession.deleted_at.is_(None))
        .one_or_none()
    )
    if not session:
        raise _err("NOT_FOUND", "Session not found", status.HTTP_404_NOT_FOUND)

    model = req.model
    web_search_enabled = bool(req.web_search_enabled)
    if not is_openai_route(model):
        web_search_enabled = False
    if web_search_enabled and not user.can_web_search:
        web_search_enabled = False

    # Load attachments (active)
    attachments = (
        db.query(Attachment)
        .filter(Attachment.session_id == session.id, Attachment.user_id == user.id, Attachment.deleted_at.is_(None), Attachment.status == "active")
        .order_by(Attachment.created_at.asc())
        .all()
    )
    image_attachments = [a for a in attachments if a.content_type in ("image/jpeg", "image/png", "image/webp")]
    if model == "deepseek" and image_attachments:
        raise _err("VALIDATION_ERROR", "DeepSeek 第一版不支持图片附件问答，请切换到 ChatGPT", status.HTTP_422_UNPROCESSABLE_ENTITY)

    # 文本允许为空：但如果没有任何附件且文本为空，则拒绝
    text = (req.text or "").strip()
    if not text and not attachments:
        raise _err("VALIDATION_ERROR", "请输入内容或添加附件", status.HTTP_422_UNPROCESSABLE_ENTITY)

    # Load recent message history
    history = (
        db.query(ChatMessage)
        .filter(ChatMessage.session_id == session.id, ChatMessage.deleted_at.is_(None))
        .order_by(ChatMessage.created_at.asc())
        .limit(50)
        .all()
    )

    # Build LLM messages
    llm_messages: list[dict] = [{"role": "system", "content": SYSTEM_PROMPT}]
    for m in history:
        llm_messages.append({"role": m.role, "content": m.content_text})

    # Attachments: include extracted text as context
    attachment_context_parts: list[str] = []
    for a in attachments:
        if a.extracted_text:
            attachment_context_parts.append(f"[附件:{a.filename}]\n{a.extracted_text}\n")
    if attachment_context_parts:
        llm_messages.append({"role": "system", "content": "以下为本会话附件提取文本，仅供参考：\n" + "\n".join(attachment_context_parts)})

    sources: list[dict] = []
    if web_search_enabled and settings.web_search_enabled:
        sources = web_search(req.text)
        if sources:
            sources_text = "\n".join([f"- {s.get('title','')} {s.get('url')}\n  {s.get('snippet','')}" for s in sources])
            llm_messages.append({"role": "system", "content": "以下为联网搜索结果来源：\n" + sources_text})

    # 首条用户消息：自动生成会话标题（与 ChatGPT 等产品一致）
    prior_user_count = sum(1 for m in history if m.role == "user")
    if prior_user_count == 0:
        session.title = derive_conversation_title(text) if text else "图片对话"
        db.add(session)

    if is_openai_route(model) and image_attachments:
        storage = get_storage_driver()
        prompt_text = text or "请描述并分析这张图片。"
        blocks: list[dict] = [{"type": "text", "text": prompt_text}]
        for a in image_attachments:
            # 优先使用“公网可访问的临时签名 URL”，避免把图片 base64 塞进请求体导致代理/链路断连。
            base = (settings.public_base_url or "").strip().rstrip("/")
            if base.startswith("https://") or base.startswith("http://"):
                t = sign_attachment_id(str(a.id))
                url = f"{base}/api/attachments/public/{a.id}?token={t}"
                blocks.append({"type": "image_url", "image_url": {"url": url}})
                continue

            try:
                raw = storage.read_bytes(bucket=a.storage_bucket, object_path=a.storage_path)
            except Exception:
                continue
            import base64
            from io import BytesIO

            # 关键：直接把原图 base64 进 data_url 容易导致请求体过大/链路被重置。
            # 这里在后端做一次“稳态压缩/缩放”，大幅降低 payload，提高图片问答成功率。
            try:
                from PIL import Image  # type: ignore

                img = Image.open(BytesIO(raw))
                # 统一转 RGB，避免 PNG/WEBP alpha 导致编码异常
                if img.mode not in ("RGB", "L"):
                    bg = Image.new("RGB", img.size, (255, 255, 255))
                    try:
                        bg.paste(img, mask=img.split()[-1])
                    except Exception:
                        bg.paste(img)
                    img = bg
                elif img.mode == "L":
                    img = img.convert("RGB")

                # 最大边 1280：够用且稳定
                img.thumbnail((1280, 1280))
                buf = BytesIO()
                img.save(buf, format="JPEG", quality=82, optimize=True)
                raw = buf.getvalue()
                content_type = "image/jpeg"

                # 如果仍然偏大（代理/链路更容易断），再更激进压一档
                if len(raw) > 900_000:
                    img.thumbnail((768, 768))
                    buf2 = BytesIO()
                    img.save(buf2, format="JPEG", quality=72, optimize=True)
                    raw = buf2.getvalue()
            except Exception:
                # Pillow 不可用或处理失败：降级使用原字节
                content_type = a.content_type

            b64 = base64.b64encode(raw).decode("ascii")
            data_url = f"data:{content_type};base64,{b64}"
            blocks.append({"type": "image_url", "image_url": {"url": data_url}})
        llm_messages.append({"role": "user", "content": blocks})
    else:
        llm_messages.append({"role": "user", "content": text})

    # Persist user message
    user_msg = ChatMessage(
        session_id=session.id,
        user_id=user.id,
        role="user",
        content_text=text,
        model=model,
        web_search_enabled=web_search_enabled,
        sources_json=[],
        deleted_at=None,
    )
    db.add(user_msg)
    db.flush()

    # Call model
    try:
        if is_openai_route(model):
            ocfg = effective_openai_config(db)
            client = OpenAIClient(api_key=ocfg.api_key, base_url=ocfg.base_url, proxy=ocfg.proxy)
            use_model = settings.openai_model_vision if image_attachments else openai_completion_model_id(model)
            resp = await client.chat(messages=llm_messages, model=use_model)
            assistant_text = resp.text
        else:
            dcfg = effective_deepseek_config(db)
            client = DeepSeekClient(api_key=dcfg.api_key, base_url=dcfg.base_url)
            resp = await client.chat_text(messages=llm_messages, model=settings.deepseek_model_text)
            assistant_text = resp.text
    except Exception as e:
        logger.exception("LLM call failed (model=%s, has_images=%s)", model, bool(image_attachments))
        db.rollback()
        raise _err("INTERNAL_ERROR", f"模型调用失败：{e}", status.HTTP_500_INTERNAL_SERVER_ERROR)

    assistant_msg = ChatMessage(
        session_id=session.id,
        user_id=user.id,
        role="assistant",
        content_text=assistant_text,
        model=model,
        web_search_enabled=web_search_enabled,
        sources_json=sources if sources else [],
        deleted_at=None,
    )
    db.add(assistant_msg)

    # usage count
    user.chat_message_count += 1
    db.add(user)
    db.add(
        UsageEvent(
            user_id=user.id,
            session_id=session.id,
            event_type="chat",
            meta_json={"model": model, "web_search_enabled": web_search_enabled},
        )
    )

    db.commit()
    db.refresh(user_msg)
    db.refresh(assistant_msg)
    db.refresh(session)

    return ChatSendResponse(
        user_message=MessageOut(
            id=str(user_msg.id),
            role=user_msg.role,
            content_text=user_msg.content_text,
            model=user_msg.model,
            web_search_enabled=bool(user_msg.web_search_enabled),
            sources=[],
            created_at=user_msg.created_at.isoformat(),
        ),
        assistant_message=MessageOut(
            id=str(assistant_msg.id),
            role=assistant_msg.role,
            content_text=assistant_msg.content_text,
            model=assistant_msg.model,
            web_search_enabled=bool(assistant_msg.web_search_enabled),
            sources=_sources_from_list(sources),
            created_at=assistant_msg.created_at.isoformat(),
        ),
        session_title=session.title or "",
    )

