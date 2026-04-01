from __future__ import annotations

from pathlib import Path


def extract_text_from_txt(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def extract_text_from_pdf(path: Path) -> str:
    from pdfminer.high_level import extract_text  # type: ignore

    try:
        text = extract_text(str(path)) or ""
        return text.strip()
    except Exception:
        return ""


def extract_text_from_docx(path: Path) -> str:
    try:
        import docx  # type: ignore

        d = docx.Document(str(path))
        parts: list[str] = []
        for p in d.paragraphs:
            if p.text:
                parts.append(p.text)
        return "\n".join(parts).strip()
    except Exception:
        return ""

