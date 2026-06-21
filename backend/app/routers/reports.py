from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user
from app.models import Listing, ListingStatus, Report, ReportStatus, User
from app.schemas import ReportCreateRequest, ReportPublic
from app.services.moderation import (
    count_distinct_listing_reports,
    maybe_auto_hide_listing_after_report,
)

router = APIRouter(prefix="/reports", tags=["reports"])


@router.post("/", response_model=ReportPublic)
def create_report(
    payload: ReportCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ReportPublic:
    if not payload.listing_id and not payload.target_user_id:
        raise HTTPException(status_code=400, detail="listing_id ou target_user_id requis")

    if payload.listing_id:
        listing = db.get(Listing, payload.listing_id)
        if not listing:
            raise HTTPException(status_code=404, detail="Annonce introuvable")
        if listing.seller_id == current_user.id:
            raise HTTPException(status_code=400, detail="Vous ne pouvez pas signaler votre propre annonce")
        if listing.status != ListingStatus.active:
            raise HTTPException(status_code=400, detail="Cette annonce n'est plus visible")

        dup = db.scalar(
            select(Report.id).where(
                Report.reporter_id == current_user.id,
                Report.listing_id == payload.listing_id,
                Report.status.in_((ReportStatus.open, ReportStatus.reviewing)),
            )
        )
        if dup:
            raise HTTPException(status_code=409, detail="Vous avez déjà signalé cette annonce")

    report = Report(
        reporter_id=current_user.id,
        target_user_id=payload.target_user_id,
        listing_id=payload.listing_id,
        reason=payload.reason.strip(),
        details=payload.details,
        status=ReportStatus.open,
    )
    db.add(report)
    db.flush()

    auto_hidden = False
    report_count = 0
    if payload.listing_id:
        auto_hidden = maybe_auto_hide_listing_after_report(
            db, listing_id=payload.listing_id, report=report
        )
        report_count = count_distinct_listing_reports(db, payload.listing_id)

    db.commit()
    db.refresh(report)

    if not auto_hidden and payload.listing_id and report_count == 1:
        from app.services.email import notify_admin_alert

        notify_admin_alert(
            subject=f"Signalement annonce #{payload.listing_id}",
            body=f"Premier signalement — motif : {report.reason}",
        )

    return ReportPublic(
        id=report.id,
        status=report.status.value,
        reason=report.reason,
        created_at=report.created_at,
    )
