"""Détection du type MIME image (navigateurs Web → application/octet-stream)."""

_ALLOWED = {"image/jpeg", "image/png", "image/webp"}


def normalize_image_content_type(content_type: str | None, filename: str | None, data: bytes) -> str:
    ct = (content_type or "").lower().split(";")[0].strip()
    if ct in _ALLOWED:
        return ct
    fn = (filename or "").lower()
    if fn.endswith(".png"):
        return "image/png"
    if fn.endswith(".webp"):
        return "image/webp"
    if fn.endswith(".jpg") or fn.endswith(".jpeg"):
        return "image/jpeg"
    if data[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if len(data) >= 8 and data[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    return "image/jpeg"
