from __future__ import annotations

import os
import uuid
from pathlib import Path

from app.settings import settings

UPLOAD_DIR = Path(__file__).resolve().parent.parent.parent / "uploads"


def _derived_s3_public_base() -> str | None:
    """URL publique Spaces/S3 déduite de la config si S3_PUBLIC_BASE_URL absent."""
    endpoint = (settings.s3_endpoint_url or "").strip().rstrip("/")
    bucket = (settings.s3_bucket or "").strip()
    if not endpoint or not bucket:
        return None
    if "digitaloceanspaces.com" in endpoint:
        from urllib.parse import urlparse

        host = urlparse(endpoint).netloc
        return f"https://{bucket}.{host}"
    region = (settings.s3_region or "us-east-1").strip()
    if "amazonaws.com" in endpoint or not endpoint.startswith("http"):
        return f"https://{bucket}.s3.{region}.amazonaws.com"
    return f"{endpoint}/{bucket}"


def public_url(key: str) -> str:
    if not key:
        return ""
    clean = key.lstrip("/")
    base = (settings.s3_public_base_url or "").strip().rstrip("/") or _derived_s3_public_base()
    if base and settings.s3_access_key:
        return f"{base}/{clean}"
    api = settings.public_base_url.rstrip("/")
    return f"{api}/uploads/{clean}"


async def save_user_avatar(*, user_id: int, content_type: str, data: bytes) -> str:
    ext = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}.get(content_type, ".jpg")
    key = f"avatars/{user_id}/{uuid.uuid4().hex}{ext}"

    if settings.s3_endpoint_url and settings.s3_access_key:
        return await _save_s3(key, data, content_type)

    dst = UPLOAD_DIR / key.replace("/", os.sep)
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(data)
    return key


def delete_local_key(key: str | None) -> None:
    if not key:
        return
    path = UPLOAD_DIR / key.replace("/", os.sep)
    if path.is_file():
        path.unlink(missing_ok=True)


def load_image_bytes(key: str) -> bytes | None:
    """Charge une image listing (disque local ou URL publique S3/CDN)."""
    if not key:
        return None
    path = UPLOAD_DIR.joinpath(*key.split("/"))
    if path.is_file():
        try:
            return path.read_bytes()
        except OSError:
            pass
    try:
        import httpx

        url = public_url(key)
        with httpx.Client(timeout=20.0, follow_redirects=True) as client:
            resp = client.get(url)
            if resp.status_code == 200 and len(resp.content) > 50:
                return resp.content
    except Exception:
        pass
    return None


async def save_kyc_document(
    *,
    application_id: int,
    doc_type: str,
    content_type: str,
    data: bytes,
) -> str:
    ext = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp", "application/pdf": ".pdf"}.get(
        content_type, ".jpg"
    )
    key = f"kyc/{application_id}/{doc_type}/{uuid.uuid4().hex}{ext}"

    if settings.s3_endpoint_url and settings.s3_access_key:
        return await _save_s3(key, data, content_type)

    dst = UPLOAD_DIR / key.replace("/", os.sep)
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(data)
    return key


async def save_image(*, listing_id: int, content_type: str, data: bytes) -> str:
    ext = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}.get(content_type, ".jpg")
    key = f"{listing_id}/{uuid.uuid4().hex}{ext}"

    if settings.s3_endpoint_url and settings.s3_access_key:
        return await _save_s3(key, data, content_type)

    dst = UPLOAD_DIR / key.replace("/", os.sep)
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(data)
    return key


async def _save_s3(key: str, data: bytes, content_type: str) -> str:
    import boto3

    client = boto3.client(
        "s3",
        endpoint_url=settings.s3_endpoint_url or None,
        aws_access_key_id=settings.s3_access_key,
        aws_secret_access_key=settings.s3_secret_key,
        region_name=settings.s3_region,
    )
    client.put_object(Bucket=settings.s3_bucket, Key=key, Body=data, ContentType=content_type)
    return key
