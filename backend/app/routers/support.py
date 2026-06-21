"""Centre d'aide — contact Équipe SombaTeka."""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.constants import TEAM_DISPLAY_NAME
from app.db import get_db
from app.deps import get_current_user
from app.models import User
from app.services.team_outreach import get_or_create_team_user

router = APIRouter(prefix="/support", tags=["support"])


@router.get("/contact")
def support_contact(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    team = get_or_create_team_user(db)
    db.commit()
    return {
        "peer_id": team.id,
        "display_name": TEAM_DISPLAY_NAME,
        "tagline": "Assistance · Modération · Comptes professionnels",
        "can_message": True,
        "response_time_hint": "Notre équipe répond généralement sous 24 h ouvrées.",
        "topics": [
            "Compte et connexion",
            "Compte professionnel (KYC)",
            "Paiements et séquestre",
            "Annonces et modération",
            "Signalement et sécurité",
        ],
    }
