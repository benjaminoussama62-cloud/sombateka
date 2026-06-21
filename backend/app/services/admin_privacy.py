"""Masquage des données personnelles clients (RGPD / confidentialité)."""

from __future__ import annotations

import re


def mask_phone(phone: str | None) -> str | None:
    if not phone:
        return None
    digits = re.sub(r"\D", "", phone)
    if len(digits) < 4:
        return "***"
    tail = digits[-2:]
    if phone.startswith("+"):
        return f"+{digits[:3]} *** *** **{tail}"
    return f"*** *** **{tail}"


def mask_user_dict(data: dict, *, phone_keys: tuple[str, ...] = ("phone_e164", "phone", "reporter_phone", "target_phone", "seller_phone", "user_phone")) -> dict:
    out = dict(data)
    for key in phone_keys:
        if key in out and out[key]:
            out[key] = mask_phone(str(out[key]))
            out[f"{key}_masked"] = True
    return out


def mask_user_row(row: dict) -> dict:
    return mask_user_dict(row)
