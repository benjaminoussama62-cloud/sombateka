from __future__ import annotations

import re
from typing import TYPE_CHECKING

from fastapi import HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import KycApplication, KycDocument, KycDocumentType
from app.schemas import KycApplicationPublic, KycDocumentPublic
from app.services.image_mime import normalize_image_content_type
from app.services.storage import public_url, save_kyc_document
from app.settings import settings

if TYPE_CHECKING:
    pass

KYC_DOC_LABELS: dict[KycDocumentType, str] = {
    KycDocumentType.rccm: "Extrait RCCM",
    KycDocumentType.tax_certificate: "Attestation fiscale (NIF)",
    KycDocumentType.national_id: "Pièce d'identité",
    KycDocumentType.shop_photo: "Photo boutique / enseigne",
    KycDocumentType.other: "Autre justificatif",
}

_ALLOWED_KYC_MIME = {"image/jpeg", "image/png", "image/webp", "application/pdf"}


def parse_legacy_business_type(raw: str) -> dict[str, str | None]:
    """Extrait RCCM / NIF des anciennes demandes (concaténés dans business_type)."""
    category = raw.split("|")[0].strip() if raw else None
    rccm = None
    tax_id = None
    m = re.search(r"RCCM:\s*([^|]+)", raw or "")
    if m:
        rccm = m.group(1).strip()
    m = re.search(r"NIF:\s*([^|]+)", raw or "")
    if m:
        tax_id = m.group(1).strip()
    return {"category": category, "rccm": rccm, "tax_id": tax_id}


def effective_kyc_fields(app_row: KycApplication) -> dict[str, str | None]:
    legacy = parse_legacy_business_type(app_row.business_type or "")
    return {
        "category": app_row.category or legacy["category"],
        "rccm": app_row.rccm or legacy["rccm"],
        "tax_id": app_row.tax_id or legacy["tax_id"],
    }


def document_to_public(doc: KycDocument) -> KycDocumentPublic:
    return KycDocumentPublic(
        id=doc.id,
        doc_type=doc.doc_type.value,
        label=KYC_DOC_LABELS.get(doc.doc_type, doc.doc_type.value),
        url=public_url(doc.storage_key),
        original_filename=doc.original_filename,
        created_at=doc.created_at,
    )


def application_to_public(app_row: KycApplication, *, documents: list[KycDocument] | None = None) -> KycApplicationPublic:
    fields = effective_kyc_fields(app_row)
    docs = documents if documents is not None else list(app_row.documents or [])
    return KycApplicationPublic(
        id=app_row.id,
        status=app_row.status.value,
        business_name=app_row.business_name,
        business_type=app_row.business_type,
        category=fields["category"],
        rccm=fields["rccm"],
        tax_id=fields["tax_id"],
        legal_representative=app_row.legal_representative,
        business_address=app_row.business_address,
        contact_phone=app_row.contact_phone,
        applicant_note=app_row.applicant_note,
        created_at=app_row.created_at,
        reviewer_note=app_row.reviewer_note,
        documents=[document_to_public(d) for d in docs],
    )


async def read_upload_file(file: UploadFile) -> tuple[bytes, str]:
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="Fichier vide")
    if len(data) > settings.upload_max_bytes:
        raise HTTPException(status_code=400, detail="Fichier trop volumineux (max 6 Mo)")
    ct = (file.content_type or "").lower().split(";")[0].strip()
    if ct == "application/pdf" or (file.filename or "").lower().endswith(".pdf"):
        if data[:4] != b"%PDF":
            raise HTTPException(status_code=400, detail="PDF invalide")
        return data, "application/pdf"
    content_type = normalize_image_content_type(file.content_type, file.filename, data)
    if content_type not in {"image/jpeg", "image/png", "image/webp"}:
        raise HTTPException(status_code=400, detail="Format non supporté (JPEG, PNG, WebP, PDF)")
    return data, content_type


async def attach_kyc_document(
    db: Session,
    *,
    application_id: int,
    doc_type: KycDocumentType,
    file: UploadFile,
) -> KycDocument:
    data, content_type = await read_upload_file(file)
    key = await save_kyc_document(
        application_id=application_id,
        doc_type=doc_type.value,
        content_type=content_type,
        data=data,
    )
    row = KycDocument(
        application_id=application_id,
        doc_type=doc_type,
        storage_key=key,
        original_filename=file.filename,
    )
    db.add(row)
    return row


def load_application_documents(db: Session, application_id: int) -> list[KycDocument]:
    return list(
        db.scalars(
            select(KycDocument)
            .where(KycDocument.application_id == application_id)
            .order_by(KycDocument.id.asc())
        ).all()
    )
