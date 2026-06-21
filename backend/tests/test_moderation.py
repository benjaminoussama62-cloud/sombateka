import pytest
from fastapi import HTTPException

from app.services.moderation import assert_content_allowed, find_banned_terms


def test_find_banned_terms():
    hits = find_banned_terms("Vente de fusil kalachnikov pas cher")
    assert "fusil" in hits or "kalachnikov" in hits or "arme" in hits


def test_assert_content_allowed_ok():
    assert_content_allowed(title="Robe été", description="Très belle")


def test_assert_content_allowed_blocked():
    with pytest.raises(HTTPException) as exc:
        assert_content_allowed(title="Faux billets USD", description="")
    assert exc.value.status_code == 400


def test_assert_image_too_small():
    from PIL import Image
    from io import BytesIO

    buf = BytesIO()
    Image.new("RGB", (50, 50), color=(255, 0, 0)).save(buf, format="JPEG")
    with pytest.raises(HTTPException):
        from app.services.moderation import assert_image_allowed

        assert_image_allowed(buf.getvalue())
