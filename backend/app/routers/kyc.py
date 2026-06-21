from datetime import datetime, timezone



from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from sqlalchemy import select

from sqlalchemy.orm import Session



from app.db import get_db

from app.deps import get_current_user

from app.models import KycApplication, KycDocumentType, KycStatus, User

from app.schemas import KycApplicationPublic, KycApplyRequest

from app.services.kyc_service import (

    application_to_public,

    attach_kyc_document,

    load_application_documents,

)



router = APIRouter(prefix="/kyc", tags=["kyc"])





def _create_application_row(

    *,

    user_id: int,

    business_name: str,

    category: str,

    rccm: str | None,

    tax_id: str | None,

    legal_representative: str | None,

    business_address: str | None,

    contact_phone: str | None,

    applicant_note: str | None,

) -> KycApplication:

    return KycApplication(

        user_id=user_id,

        business_name=business_name.strip(),

        business_type=category.strip(),

        category=category.strip(),

        rccm=rccm.strip() if rccm else None,

        tax_id=tax_id.strip() if tax_id else None,

        legal_representative=legal_representative.strip() if legal_representative else None,

        business_address=business_address.strip() if business_address else None,

        contact_phone=contact_phone.strip() if contact_phone else None,

        applicant_note=applicant_note.strip() if applicant_note else None,

        status=KycStatus.pending,

    )





async def _save_optional_docs(

    db: Session,

    app_row: KycApplication,

    *,

    doc_rccm: UploadFile | None,

    doc_tax: UploadFile | None,

    doc_id: UploadFile | None,

    doc_shop: UploadFile | None,

) -> None:

    pairs = [

        (doc_rccm, KycDocumentType.rccm),

        (doc_tax, KycDocumentType.tax_certificate),

        (doc_id, KycDocumentType.national_id),

        (doc_shop, KycDocumentType.shop_photo),

    ]

    for upload, doc_type in pairs:

        if upload is None or not upload.filename:

            continue

        await attach_kyc_document(db, application_id=app_row.id, doc_type=doc_type, file=upload)





@router.post("/apply", response_model=KycApplicationPublic)

async def apply_official(

    business_name: str = Form(...),

    business_type: str = Form(...),

    rccm: str | None = Form(default=None),

    tax_id: str | None = Form(default=None),

    legal_representative: str | None = Form(default=None),

    business_address: str | None = Form(default=None),

    contact_phone: str | None = Form(default=None),

    applicant_note: str | None = Form(default=None),

    doc_rccm: UploadFile | None = File(default=None),

    doc_tax: UploadFile | None = File(default=None),

    doc_id: UploadFile | None = File(default=None),

    doc_shop: UploadFile | None = File(default=None),

    current_user: User = Depends(get_current_user),

    db: Session = Depends(get_db),

) -> KycApplicationPublic:

    if len(business_name.strip()) < 2:

        raise HTTPException(status_code=400, detail="Nom d'entreprise requis")

    existing = db.scalar(

        select(KycApplication)

        .where(KycApplication.user_id == current_user.id, KycApplication.status == KycStatus.pending)

    )

    if existing:

        raise HTTPException(status_code=409, detail="Une demande est déjà en cours")



    has_id_doc = doc_id is not None and bool(doc_id.filename)

    has_rccm_doc = doc_rccm is not None and bool(doc_rccm.filename)

    if not has_id_doc or not has_rccm_doc:

        raise HTTPException(

            status_code=400,

            detail="Joignez au minimum l'extrait RCCM et une pièce d'identité",

        )



    app_row = _create_application_row(

        user_id=current_user.id,

        business_name=business_name,

        category=business_type,

        rccm=rccm,

        tax_id=tax_id,

        legal_representative=legal_representative,

        business_address=business_address,

        contact_phone=contact_phone,

        applicant_note=applicant_note,

    )

    db.add(app_row)

    db.flush()

    await _save_optional_docs(

        db,

        app_row,

        doc_rccm=doc_rccm,

        doc_tax=doc_tax,

        doc_id=doc_id,

        doc_shop=doc_shop,

    )

    db.commit()

    db.refresh(app_row)

    from app.services.email import notify_admin_alert

    notify_admin_alert(
        subject=f"Nouvelle demande KYC #{app_row.id}",
        body=(
            f"Entreprise : {app_row.business_name}\n"
            f"Type : {app_row.business_type}\n"
            f"Demandeur : user #{current_user.id} ({current_user.phone_e164})"
        ),
    )

    docs = load_application_documents(db, app_row.id)

    return application_to_public(app_row, documents=docs)





@router.post("/apply/json", response_model=KycApplicationPublic)

def apply_official_json(

    payload: KycApplyRequest,

    current_user: User = Depends(get_current_user),

    db: Session = Depends(get_db),

) -> KycApplicationPublic:

    """Compatibilité clients sans upload multipart (documents requis via /apply)."""

    existing = db.scalar(

        select(KycApplication)

        .where(KycApplication.user_id == current_user.id, KycApplication.status == KycStatus.pending)

    )

    if existing:

        raise HTTPException(status_code=409, detail="Une demande est déjà en cours")



    app_row = _create_application_row(

        user_id=current_user.id,

        business_name=payload.business_name,

        category=payload.business_type.strip(),

        rccm=payload.rccm,

        tax_id=payload.tax_id,

        legal_representative=payload.legal_representative,

        business_address=payload.business_address,

        contact_phone=payload.contact_phone,

        applicant_note=payload.applicant_note,

    )

    db.add(app_row)

    db.commit()

    db.refresh(app_row)

    from app.services.email import notify_admin_alert

    notify_admin_alert(
        subject=f"Nouvelle demande KYC #{app_row.id}",
        body=(
            f"Entreprise : {app_row.business_name}\n"
            f"Type : {app_row.business_type}\n"
            f"Demandeur : user #{current_user.id} ({current_user.phone_e164})"
        ),
    )

    return application_to_public(app_row, documents=[])





@router.get("/me", response_model=KycApplicationPublic | None)

def my_kyc(

    current_user: User = Depends(get_current_user),

    db: Session = Depends(get_db),

):

    row = db.scalar(

        select(KycApplication)

        .where(KycApplication.user_id == current_user.id)

        .order_by(KycApplication.id.desc())

    )

    if not row:

        return None

    docs = load_application_documents(db, row.id)

    return application_to_public(row, documents=docs)


