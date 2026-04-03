from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "Family AI Assistant"
    environment: str = "dev"
    log_level: str = "INFO"

    cors_allow_origins: str = ""
    public_base_url: str = ""

    database_url: str

    jwt_secret: str
    jwt_algorithm: str = "HS256"
    jwt_expires_minutes: int = 43200

    admin_username: str = "admin"
    admin_password: str = "admin"

    openai_api_key: str = ""
    openai_base_url: str = "https://api.openai.com/v1"
    # 代理（若你本机浏览器能访问但后端请求不通，通常是后端进程未走系统代理）
    # 支持形如：http://127.0.0.1:7890 或 socks5://127.0.0.1:7890
    openai_proxy: str = ""
    # ChatGPT 路线：chatgpt-5.2 / chatgpt-5.4 分别映射到以下 OpenAI model id
    # 默认值指向更“稳态”的两个版本；如你使用兼容网关/私有部署，可在 .env 覆盖
    openai_model_chatgpt_52: str = "gpt-5.2"
    openai_model_chatgpt_54: str = "gpt-5.4"
    # 图片问答：当消息包含图片附件时优先使用该模型（需支持 image_url blocks）
    openai_model_vision: str = "gpt-5.4"

    deepseek_api_key: str = ""
    deepseek_base_url: str = "https://api.deepseek.com"
    deepseek_proxy: str = ""
    # 官方 API：deepseek-chat 为对话模型（随平台升级指向当前主力版本）；deepseek-reasoner 为推理模式
    deepseek_model_text: str = "deepseek-chat"

    # Google AI Studio / Gemini API（generativelanguage.googleapis.com）
    gemini_api_key: str = ""
    gemini_base_url: str = "https://generativelanguage.googleapis.com/v1beta"
    gemini_proxy: str = ""
    # 路由 gemini-flash / gemini-pro 映射到的官方 model id（可在 .env 覆盖）
    gemini_model_flash: str = "gemini-3-flash-preview"
    gemini_model_pro: str = "gemini-3.1-pro-preview"

    web_search_enabled: bool = True
    web_search_timeout_seconds: int = 8
    web_search_max_results: int = 5

    storage_driver: str = "local"  # local | supabase
    local_storage_root: str = "./.data/uploads"

    supabase_url: str = ""
    supabase_service_role_key: str = ""
    supabase_bucket: str = "family-ai-attachments"

    # Tencent Cloud COS (S3-compatible-ish, but uses its own SDK for signing)
    # When STORAGE_DRIVER=cos, client uploads directly to COS via presigned PUT URLs.
    cos_region: str = ""
    cos_bucket: str = ""
    cos_secret_id: str = ""
    cos_secret_key: str = ""
    # Optional: custom endpoint domain (without scheme), e.g. "cos.ap-singapore.myqcloud.com"
    cos_endpoint: str = ""
    # Optional: public base for downloads (e.g. Cloudflare) if you use public-read objects.
    # If empty, we will prefer presigned GET URLs for model-side downloading.
    cos_public_base_url: str = ""

    # 为 true 时 Cookie 带 Secure，仅能在 HTTPS 下写入。直接用 http://IP:8000 访问后台会无法登录（无限跳回登录页）。
    # 全站 HTTPS（或反代终止 TLS）时请在 .env 设为 true。
    session_cookie_secure: bool = False
    session_cookie_samesite: str = "lax"

    # Brave 等敏感字段落库加密用（Fernet URL-safe base64 密钥，见 cryptography 文档）
    field_encryption_fernet_key: str = ""

    # ---------- 智能化流水线（见 docs / 需求文档）----------
    feature_task_classification: bool = True
    feature_structured_prompts: bool = True
    feature_context_compression: bool = True
    feature_output_validation: bool = True
    feature_search_auto_trigger: bool = True
    feature_search_structured_injection: bool = True
    prompt_templates_hot_reload: bool = False
    max_context_turns: int = 20
    context_history_token_budget: int = 24000
    classifier_model: str = "gpt-4o-mini"
    # 无 OpenAI Key、用 DeepSeek 做任务分类时的 model（建议对话模型用 reasoner 时仍保持轻量分类）
    classifier_model_deepseek: str = "deepseek-chat"
    classifier_timeout_ms: int = 2500


settings = Settings()  # type: ignore[call-arg]

