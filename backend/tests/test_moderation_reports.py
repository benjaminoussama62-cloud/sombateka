from sqlalchemy import select

from app.models import Listing, ListingStatus, Report, ReportStatus, User, UserRole
from app.services.moderation import maybe_auto_hide_listing_after_report


def test_auto_hide_after_threshold(db_session):
    seller = User(phone_e164="+243911111001", role=UserRole.user)
    r1 = User(phone_e164="+243911111002", role=UserRole.user)
    r2 = User(phone_e164="+243911111003", role=UserRole.user)
    r3 = User(phone_e164="+243911111004", role=UserRole.user)
    db_session.add_all([seller, r1, r2, r3])
    db_session.flush()

    listing = Listing(
        title="Test arnaque",
        city="Kinshasa",
        price_cdf=1000,
        seller_id=seller.id,
        status=ListingStatus.active,
    )
    db_session.add(listing)
    db_session.flush()

    for u in (r1, r2):
        db_session.add(
            Report(
                reporter_id=u.id,
                listing_id=listing.id,
                reason="arnaque",
                status=ReportStatus.open,
            )
        )
    db_session.commit()

    last = Report(reporter_id=r3.id, listing_id=listing.id, reason="escroc", status=ReportStatus.open)
    db_session.add(last)
    db_session.flush()
    hidden = maybe_auto_hide_listing_after_report(db_session, listing_id=listing.id, report=last)
    db_session.commit()

    assert hidden is True
    listing = db_session.get(Listing, listing.id)
    assert listing.status == ListingStatus.hidden
    assert listing.auto_hidden_reason is not None
