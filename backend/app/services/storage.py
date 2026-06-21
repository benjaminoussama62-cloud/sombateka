from __future__ import annotations

import os
import uuid
from pathlib import Path

from app.settings import settings

UPLOAD_DIR = Path(__file__).resolve().parent.parent.parent / "uploads"


def public_url(key: str) -> str:
    if settings.s3_public_base_url:
        base = settings.s3_public_base_url.rstrip("/")
        return f"{base}/{key}"
    base = settings.public_base_url.rstrip("/")
    return f"{base}/uploads/{key}"


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
