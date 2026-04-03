#!/usr/bin/env python3
"""
将数据库中的管理员账号与当前 .env 的 ADMIN_USERNAME / ADMIN_PASSWORD 对齐。
用法（在 backend 目录、已激活 venv）：
  python reset_admin_password.py
"""
from __future__ import annotations

from app.core.config import settings
from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models.user import User


def main() -> None:
    db = SessionLocal()
    try:
        target = (settings.admin_username or "").strip()
        pwd = settings.admin_password or ""
        if not target or not pwd:
            raise SystemExit("请在 .env 中设置 ADMIN_USERNAME 与 ADMIN_PASSWORD（非空）")

        u = db.query(User).filter(User.role == "admin").order_by(User.created_at.asc()).first()
        if u is None:
            u = User(
                username=target,
                password_hash=hash_password(pwd),
                role="admin",
                is_active=True,
                must_change_password=False,
                can_web_search=True,
                can_upload=True,
                default_model="chatgpt-5.2",
            )
            db.add(u)
            print(f"已创建管理员账号：{target}")
        else:
            u.username = target
            u.password_hash = hash_password(pwd)
            u.is_active = True
            u.must_change_password = False
            db.add(u)
            print(f"已重置管理员账号：{target}")

        db.commit()
    finally:
        db.close()


if __name__ == "__main__":
    main()
