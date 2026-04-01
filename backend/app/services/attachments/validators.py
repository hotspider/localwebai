from __future__ import annotations

from dataclasses import dataclass


ALLOWED_CONTENT_TYPES = {
    "application/pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "text/plain",
    "image/jpeg",
    "image/png",
    "image/webp",
}

MAX_FILE_BYTES = 10 * 1024 * 1024
MAX_ATTACHMENTS_PER_SESSION = 5


@dataclass(frozen=True)
class AttachmentPolicy:
    allowed_content_types: set[str] = None  # type: ignore[assignment]
    max_file_bytes: int = MAX_FILE_BYTES
    max_attachments_per_session: int = MAX_ATTACHMENTS_PER_SESSION


POLICY = AttachmentPolicy(allowed_content_types=ALLOWED_CONTENT_TYPES)


def validate_attachment_request(*, content_type: str, size_bytes: int) -> None:
    if content_type not in POLICY.allowed_content_types:
        raise ValueError("Unsupported file type")
    if size_bytes > POLICY.max_file_bytes:
        raise ValueError("File too large")

