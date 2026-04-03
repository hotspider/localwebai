from __future__ import annotations

import os
import base64
from dataclasses import dataclass
from pathlib import Path

import httpx
try:
    from qcloud_cos import CosConfig, CosS3Client  # type: ignore
except Exception:  # pragma: no cover
    CosConfig = None  # type: ignore[assignment]
    CosS3Client = None  # type: ignore[assignment]

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

    def presign_get(self, *, bucket: str, object_path: str, expires_seconds: int) -> str:
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

    def presign_get(self, *, bucket: str, object_path: str, expires_seconds: int) -> str:
        # Local dev: model cannot fetch localhost. Callers should fall back to base64.
        return ""

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

    def presign_get(self, *, bucket: str, object_path: str, expires_seconds: int) -> str:
        # 当前实现未做客户端直传/签名下载；让调用方走后端 /api/attachments/public/{id}?token=...
        return ""

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


class CosStorage(StorageDriver):
    def __init__(self, *, region: str, secret_id: str, secret_key: str, endpoint: str | None = None) -> None:
        if CosConfig is None or CosS3Client is None:
            raise RuntimeError("COS SDK not installed (missing cos-python-sdk-v5 / qcloud_cos)")
        self.bucket = settings.cos_bucket
        self.region = region
        self._public_base = (settings.cos_public_base_url or "").strip().rstrip("/")

        cfg = CosConfig(Region=region, SecretId=secret_id, SecretKey=secret_key, Scheme="https")
        # SDK 支持自定义 Endpoint，但不同版本参数名不一致；这里用默认域名最稳。
        # 若你必须使用自定义域名（例如内网/代理），可以在后续按实际 SDK 版本调整。
        self.client = CosS3Client(cfg)
        self.endpoint = (endpoint or "").strip()

    def make_object_path(self, *, user_id: str, session_id: str, attachment_id: str, filename: str) -> str:
        safe_name = filename.replace("/", "_")
        return f"u/{user_id}/s/{session_id}/{attachment_id}/{safe_name}"

    def presign_put(self, *, bucket: str, object_path: str, content_type: str) -> UploadSpec:
        # Client uploads directly to COS with presigned PUT URL.
        # Important: include Content-Type in headers; do not add Content-Length.
        url = self.client.get_presigned_url(
            Method="PUT",
            Bucket=bucket,
            Key=object_path,
            Expired=60 * 10,
            Headers={"Content-Type": content_type},
        )
        return UploadSpec(method="PUT", url=url, headers={"Content-Type": content_type})

    def presign_get(self, *, bucket: str, object_path: str, expires_seconds: int) -> str:
        # Prefer stable public base (e.g. Cloudflare) if configured; otherwise use presigned GET.
        if self._public_base:
            return f"{self._public_base}/{object_path.lstrip('/')}"
        return self.client.get_presigned_url(Method="GET", Bucket=bucket, Key=object_path, Expired=int(expires_seconds))

    def resolve_local_path(self, *, bucket: str, object_path: str) -> Path:
        return Path("/dev/null")

    def delete_object(self, *, bucket: str, object_path: str) -> None:
        try:
            self.client.delete_object(Bucket=bucket, Key=object_path)
        except Exception:
            return

    def read_bytes(self, *, bucket: str, object_path: str) -> bytes:
        r = self.client.get_object(Bucket=bucket, Key=object_path)
        body = r.get("Body")
        if body is None:
            raise RuntimeError("COS object body missing")
        return body.get_raw_stream().read()


def get_storage_driver() -> StorageDriver:
    if settings.storage_driver == "local":
        return LocalStorage(settings.local_storage_root)
    if settings.storage_driver == "supabase":
        if not settings.supabase_url or not settings.supabase_service_role_key:
            raise RuntimeError("Supabase storage not configured")
        return SupabaseStorage(url=settings.supabase_url, service_role_key=settings.supabase_service_role_key)
    if settings.storage_driver == "cos":
        if not settings.cos_region or not settings.cos_bucket or not settings.cos_secret_id or not settings.cos_secret_key:
            raise RuntimeError("COS storage not configured")
        return CosStorage(
            region=settings.cos_region,
            secret_id=settings.cos_secret_id,
            secret_key=settings.cos_secret_key,
            endpoint=settings.cos_endpoint or None,
        )
    raise RuntimeError("Unsupported storage driver")

