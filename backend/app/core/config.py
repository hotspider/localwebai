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
    deepseek_model_text: str = "deepseek-chat"

    web_search_enabled: bool = True
    web_search_timeout_seconds: int = 8
    web_search_max_results: int = 5

    storage_driver: str = "local"  # local | supabase
    local_storage_root: str = "./.data/uploads"

    supabase_url: str = ""
    supabase_service_role_key: str = ""
    supabase_bucket: str = "family-ai-attachments"

    session_cookie_secure: bool = True
    session_cookie_samesite: str = "lax"


settings = Settings()  # type: ignore[call-arg]

