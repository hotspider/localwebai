from __future__ import annotations

import os
import base64
from dataclasses import dataclass
from pathlib import Path

import httpx

from app.core.config import settings


@dataclass(frozen=True)
class UploadSpec:
    method: str
    url: str
    headers: dict[str, str]


class StorageDriver:
    def make_object_path(self, *, user_id: str, session_id: str, attachment_id: str, filename: str) -> str:
        raise NotImplementedError

    def presign_put(self, *, bucket: str, object_path: str, content_type: str) -> UploadSpec:
        raise NotImplementedError

    def resolve_local_path(self, *, bucket: str, object_path: str) -> Path:
        raise NotImplementedError

    def delete_object(self, *, bucket: str, object_path: str) -> None:
        raise NotImplementedError

    def read_bytes(self, *, bucket: str, object_path: str) -> bytes:
        raise NotImplementedError


class LocalStorage(StorageDriver):
    def __init__(self, root_dir: str) -> None:
        self.root_dir = Path(root_dir).resolve()

    def make_object_path(self, *, user_id: str, session_id: str, attachment_id: str, filename: str) -> str:
        safe_name = filename.replace("/", "_")
        return f"u/{user_id}/s/{session_id}/{attachment_id}/{safe_name}"

    def presign_put(self, *, bucket: str, object_path: str, content_type: str) -> UploadSpec:
        # Local dev: client PUTs to backend endpoint which writes to disk.
        url = f"/api/attachments/upload/{bucket}/{object_path}"
        return UploadSpec(method="PUT", url=url, headers={"Content-Type": content_type})

    def resolve_local_path(self, *, bucket: str, object_path: str) -> Path:
        return (self.root_dir / bucket / object_path).resolve()

    def delete_object(self, *, bucket: str, object_path: str) -> None:
        p = self.resolve_local_path(bucket=bucket, object_path=object_path)
        try:
            p.unlink()
        except FileNotFoundError:
            return

    def read_bytes(self, *, bucket: str, object_path: str) -> bytes:
        p = self.resolve_local_path(bucket=bucket, object_path=object_path)
        return p.read_bytes()


class SupabaseStorage(StorageDriver):
    def __init__(self, *, url: str, service_role_key: str) -> None:
        self.url = url.rstrip("/")
        self.key = service_role_key

    def make_object_path(self, *, user_id: str, session_id: str, attachment_id: str, filename: str) -> str:
        safe_name = filename.replace("/", "_")
        return f"u/{user_id}/s/{session_id}/{attachment_id}/{safe_name}"

    def presign_put(self, *, bucket: str, object_path: str, content_type: str) -> UploadSpec:
        # 第一版最简单且安全：客户端 PUT 到后端，由后端用 service_role 上传到 Supabase
        url = f"/api/attachments/upload/{bucket}/{object_path}"
        return UploadSpec(method="PUT", url=url, headers={"Content-Type": content_type})

    def resolve_local_path(self, *, bucket: str, object_path: str) -> Path:
        # not used
        return Path("/dev/null")

    def delete_object(self, *, bucket: str, object_path: str) -> None:
        # Supabase Storage delete object
        api = f"{self.url}/storage/v1/object/{bucket}/{object_path}"
        headers = {"Authorization": f"Bearer {self.key}"}
        with httpx.Client(timeout=30) as client:
            r = client.delete(api, headers=headers)
            if r.status_code not in (200, 204, 404):
                r.raise_for_status()

    def read_bytes(self, *, bucket: str, object_path: str) -> bytes:
        api = f"{self.url}/storage/v1/object/{bucket}/{object_path}"
        headers = {"Authorization": f"Bearer {self.key}"}
        with httpx.Client(timeout=60) as client:
            r = client.get(api, headers=headers)
            r.raise_for_status()
            return r.content

    def upload_bytes(self, *, bucket: str, object_path: str, content_type: str, data: bytes) -> None:
        api = f"{self.url}/storage/v1/object/{bucket}/{object_path}"
        headers = {"Authorization": f"Bearer {self.key}", "Content-Type": content_type}
        with httpx.Client(timeout=120) as client:
            r = client.post(api, headers=headers, content=data)
            r.raise_for_status()


def get_storage_driver() -> StorageDriver:
    if settings.storage_driver == "local":
        return LocalStorage(settings.local_storage_root)
    if settings.storage_driver == "supabase":
        if not settings.supabase_url or not settings.supabase_service_role_key:
            raise RuntimeError("Supabase storage not configured")
        return SupabaseStorage(url=settings.supabase_url, service_role_key=settings.supabase_service_role_key)
    raise RuntimeError("Unsupported storage driver")

