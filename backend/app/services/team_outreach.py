"""Messages et notifications envoyés par l'équipe SombaTeka (centre d'aide)."""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.constants import TEAM_DISPLAY_NAME, TEAM_SOMBA_TEKA_PHONE
from app.models import Message, User, UserRole
from app.services.notifications import push_notification

TEAM_MESSAGE_KIND = "team"
_SIGNATURE = f"\n\n— {TEAM_DISPLAY_NAME}\nAssistance · Modération · Comptes professionnels"


def get_or_create_team_user(db: Session) -> User:
    team = db.scalar(select(User).where(User.phone_e164 == TEAM_SOMBA_TEKA_PHONE))
    if team:
        if team.role != UserRole.support:
            team.role = UserRole.support
        if team.display_name != TEAM_DISPLAY_NAME:
            team.display_name = TEAM_DISPLAY_NAME
        team.official_name = TEAM_DISPLAY_NAME
        team.privacy_allow_messages = True
        team.is_phone_verified = True
        team.is_banned = False
        return team
    team = User(
        phone_e164=TEAM_SOMBA_TEKA_PHONE,
        role=UserRole.support,
        display_name=TEAM_DISPLAY_NAME,
        official_name=TEAM_DISPLAY_NAME,
        is_phone_verified=True,
        privacy_allow_messages=True,
        privacy_profile_public=False,
        privacy_show_phone=False,
    )
    db.add(team)
    db.flush()
    return team


def is_team_user(user: User | None) -> bool:
    return user is not None and user.role == UserRole.support


def peer_display_name(user: User) -> str:
    if is_team_user(user):
        return TEAM_DISPLAY_NAME
    return user.display_name or user.official_name or user.phone_e164


def notify_user(
    db: Session,
    *,
    user_id: int,
    notif_type: str,
    title: str,
    body: str,
    message: str,
    listing_id: int | None = None,
) -> None:
    """Envoie une notification in-app complète + un message détaillé de l'équipe SombaTeka."""
    recipient = db.get(User, user_id)
    if not recipient:
        return
    team = get_or_create_team_user(db)
    now = datetime.now(timezone.utc)
    full_message = message.strip()
    if not full_message.endswith(TEAM_DISPLAY_NAME):
        full_message += _SIGNATURE

    db.add(
        Message(
            sender_id=team.id,
            recipient_id=user_id,
            listing_id=None,
            content=full_message,
            kind=TEAM_MESSAGE_KIND,
            is_read=False,
            created_at=now,
            updated_at=now,
        )
    )
    push_notification(
        db,
        user_id=user_id,
        type=notif_type,
        title=title,
        body=body.strip(),
        listing_id=listing_id,
        commit=False,
    )
    if recipient.email and getattr(recipient, "email_verified", False):
        from app.services.email import send_user_notification_email

        send_user_notification_email(email=recipient.email, title=title, body=body.strip())


def notify_kyc_approved(db: Session, *, user_id: int, business_name: str) -> None:
    title = "Compte professionnel approuvé"
    body = (
        f"Félicitations ! Votre demande de compte professionnel « {business_name} » a été validée par "
        f"{TEAM_DISPLAY_NAME}. Vous disposez désormais du badge vendeur officiel, pouvez recevoir les paiements "
        f"Mobile Money (MTN / Orange) directement dans l'application et bénéficier d'une visibilité renforcée. "
        f"Consultez vos messages pour le détail complet et répondez-nous en cas de question."
    )
    message = (
        f"Bonjour,\n\n"
        f"Nous avons le plaisir de vous informer que votre demande de compte professionnel "
        f"« {business_name} » a été examinée et approuvée par {TEAM_DISPLAY_NAME}.\n\n"
        f"Ce que cela change pour vous :\n"
        f"• Votre profil affiche le statut vendeur officiel vérifié\n"
        f"• Vous pouvez encaisser via Mobile Money in-app (MTN Money, Orange Money)\n"
        f"• Vos annonces bénéficient d'une meilleure visibilité dans le catalogue\n"
        f"• Le chat acheteur s'ouvre selon les règles des comptes professionnels\n\n"
        f"Prochaines étapes : vérifiez que vos informations boutique sont à jour, publiez vos annonces "
        f"avec des photos claires et des descriptions complètes, et respectez les conditions d'utilisation "
        f"de SombaTeka.\n\n"
        f"Ce fil de discussion reste ouvert : écrivez-nous ici pour toute question sur votre compte pro, "
        f"les paiements ou la modération.\n\n"
        f"Bienvenue parmi les vendeurs officiels SombaTeka !"
    )
    notify_user(db, user_id=user_id, notif_type="kyc_approved", title=title, body=body, message=message)


def notify_kyc_rejected(db: Session, *, user_id: int, business_name: str, note: str | None) -> None:
    motif = note.strip() if note and note.strip() else "Non précisé — contactez-nous pour plus de détails."
    title = "Demande professionnelle non approuvée"
    body = (
        f"Après vérification de votre dossier « {business_name} », {TEAM_DISPLAY_NAME} ne peut pas accorder "
        f"le statut vendeur officiel pour le moment. Motif communiqué : {motif} "
        f"Vous pouvez corriger votre dossier et soumettre une nouvelle demande, ou répondre à ce message "
        f"pour obtenir des précisions. Le message complet est disponible dans vos discussions."
    )
    message = (
        f"Bonjour,\n\n"
        f"Nous avons terminé l'examen de votre demande de compte professionnel « {business_name} ».\n\n"
        f"Décision : votre demande n'est pas approuvée à ce stade.\n\n"
        f"Motif indiqué par notre équipe :\n{motif}\n\n"
        f"Cela peut être lié à des pièces manquantes, des informations incohérentes ou un dossier incomplet. "
        f"Vous conservez votre compte utilisateur standard : vous pouvez continuer à acheter, vendre en mode "
        f"particulier et utiliser l'application normalement.\n\n"
        f"Que faire ensuite ?\n"
        f"1. Relisez les conditions pour devenir vendeur officiel dans l'application\n"
        f"2. Corrigez les éléments mentionnés dans le motif ci-dessus\n"
        f"3. Soumettez une nouvelle demande KYC depuis votre profil\n"
        f"4. Ou répondez directement à ce message — nous vous guiderons étape par étape\n\n"
        f"Nous restons disponibles pour vous accompagner."
    )
    notify_user(db, user_id=user_id, notif_type="kyc_rejected", title=title, body=body, message=message)


def notify_account_banned(db: Session, *, user_id: int, reason: str | None) -> None:
    motif = reason.strip() if reason and reason.strip() else "Violation des règles d'utilisation de la plateforme."
    title = "Votre compte SombaTeka est suspendu"
    body = (
        f"{TEAM_DISPLAY_NAME} a suspendu l'accès à votre compte SombaTeka. Vous ne pouvez plus publier, "
        f"acheter ni envoyer de messages tant que la suspension est active. Motif : {motif} "
        f"Si vous souhaitez contester cette décision ou obtenir des explications, répondez au message "
        f"complet reçu dans vos discussions avec l'équipe SombaTeka."
    )
    message = (
        f"Bonjour,\n\n"
        f"Nous vous informons que {TEAM_DISPLAY_NAME} a suspendu votre compte SombaTeka.\n\n"
        f"Conséquences immédiates :\n"
        f"• Connexion possible mais fonctionnalités limitées ou bloquées selon la gravité\n"
        f"• Impossibilité de publier de nouvelles annonces\n"
        f"• Suspension des échanges commerciaux sur la plateforme\n"
        f"• Vos annonces peuvent être masquées ou retirées du catalogue\n\n"
        f"Motif de la suspension :\n{motif}\n\n"
        f"Cette mesure vise à protéger la communauté (arnaques, contenus interdits, harcèlement, "
        f"non-respect répété des règles, etc.).\n\n"
        f"Pour faire valoir vos droits :\n"
        f"Répondez à ce message en expliquant votre situation avec courtoisie et, si possible, "
        f"des éléments factuels. Notre équipe de modération relira votre dossier sous un délai raisonnable.\n\n"
        f"Merci de votre compréhension."
    )
    notify_user(db, user_id=user_id, notif_type="account_banned", title=title, body=body, message=message)


def notify_account_unbanned(db: Session, *, user_id: int) -> None:
    title = "Votre compte est réactivé"
    body = (
        f"Bonne nouvelle : {TEAM_DISPLAY_NAME} a réactivé votre compte SombaTeka. Vous pouvez à nouveau "
        f"utiliser l'application, publier des annonces et échanger avec les autres utilisateurs, dans le "
        f"respect des règles de la communauté. Consultez le message complet dans vos discussions pour les "
        f"recommandations de notre équipe."
    )
    message = (
        f"Bonjour,\n\n"
        f"Votre compte SombaTeka a été réactivé par {TEAM_DISPLAY_NAME}.\n\n"
        f"Vous retrouvez l'accès aux fonctionnalités habituelles : navigation, publication d'annonces, "
        f"messagerie et, le cas échéant, votre statut vendeur si celui-ci n'a pas été modifié.\n\n"
        f"Nous vous rappelons :\n"
        f"• Respectez les conditions générales et la charte de modération\n"
        f"• Publiez des annonces honnêtes avec photos et prix réels\n"
        f"• Traitez les acheteurs et vendeurs avec courtoisie\n"
        f"• En cas de litige, privilégiez le dialogue ou contactez-nous ici\n\n"
        f"Merci de votre patience pendant la procédure de vérification. "
        f"Nous sommes heureux de vous retrouver sur SombaTeka.\n\n"
        f"Ce fil reste ouvert pour toute question."
    )
    notify_user(db, user_id=user_id, notif_type="account_unbanned", title=title, body=body, message=message)


def notify_official_revoked(db: Session, *, user_id: int) -> None:
    title = "Statut vendeur officiel retiré"
    body = (
        f"{TEAM_DISPLAY_NAME} a retiré votre statut de vendeur officiel sur SombaTeka. Votre compte "
        f"reste actif en tant qu'utilisateur standard ; vos annonces peuvent rester en ligne selon les "
        f"règles classiques, sans les avantages Mobile Money in-app ni le badge officiel. "
        f"Lisez le message complet dans vos discussions pour comprendre les suites possibles."
    )
    message = (
        f"Bonjour,\n\n"
        f"Nous vous informons que {TEAM_DISPLAY_NAME} a révoqué votre statut de vendeur officiel.\n\n"
        f"Ce qui change :\n"
        f"• Le badge « vendeur officiel » n'apparaît plus sur votre profil\n"
        f"• Les paiements Mobile Money intégrés ne sont plus disponibles pour vos ventes\n"
        f"• Vous continuez à vendre en tant qu'utilisateur particulier, selon les règles standard\n"
        f"• Les annonces déjà publiées peuvent rester visibles ou être révisées par la modération\n\n"
        f"Cette décision peut faire suite à un non-respect des obligations pro, des signalements "
        f"ou à une demande de votre part.\n\n"
        f"Vous pouvez :\n"
        f"• Continuer à utiliser SombaTeka normalement en mode utilisateur\n"
        f"• Soumettre une nouvelle demande KYC plus tard si votre situation évolue\n"
        f"• Nous écrire ici pour demander des précisions ou un recours\n\n"
        f"Nous restons à votre écoute."
    )
    notify_user(db, user_id=user_id, notif_type="official_revoked", title=title, body=body, message=message)


def notify_listing_hidden(db: Session, *, user_id: int, listing_title: str, listing_id: int) -> None:
    title = f"Annonce masquée : {listing_title[:60]}"
    body = (
        f"L'annonce « {listing_title} » a été masquée par {TEAM_DISPLAY_NAME} et n'est plus visible "
        f"dans le catalogue public. Cela peut suivre un signalement ou un contrôle de modération "
        f"(contenu interdit, prix trompeur, doublon, etc.). Consultez le message détaillé dans vos "
        f"discussions pour savoir comment corriger la situation ou demander une révision."
    )
    message = (
        f"Bonjour,\n\n"
        f"Nous vous informons que votre annonce « {listing_title} » a été masquée "
        f"par {TEAM_DISPLAY_NAME} et n'apparaît plus dans les résultats de recherche.\n\n"
        f"Raisons fréquentes :\n"
        f"• Contenu interdit ou trompeur (produits illégaux, arnaque, fausses photos)\n"
        f"• Signalement d'un utilisateur confirmé par notre équipe\n"
        f"• Non-respect des catégories ou des règles de publication\n"
        f"• Doublon ou spam d'annonces identiques\n\n"
        f"Que pouvez-vous faire ?\n"
        f"1. Vérifiez le titre, la description, les photos et le prix de l'annonce\n"
        f"2. Modifiez l'annonce pour la mettre en conformité, puis contactez-nous si besoin\n"
        f"3. Répondez à ce message pour demander une révision ou un rétablissement\n\n"
        f"Les commandes en cours, le cas échéant, doivent être traitées selon vos engagements "
        f"envers les acheteurs.\n\n"
        f"Merci de contribuer à une marketplace sûre pour tous."
    )
    notify_user(
        db,
        user_id=user_id,
        notif_type="listing_hidden",
        title=title,
        body=body,
        message=message,
        listing_id=listing_id,
    )


def notify_warning(db: Session, *, user_id: int, text: str) -> None:
    detail = text.strip()
    title = "Avertissement officiel — SombaTeka"
    body = (
        f"{TEAM_DISPLAY_NAME} vous adresse un avertissement formel concernant votre activité sur SombaTeka. "
        f"Contenu : {detail} "
        f"Un non-respect répété des règles peut entraîner la suspension du compte ou le retrait "
        f"de votre statut vendeur. Lisez le message complet dans vos discussions et répondez-nous "
        f"si vous souhaitez clarifier la situation."
    )
    message = (
        f"Bonjour,\n\n"
        f"{TEAM_DISPLAY_NAME} vous adresse un avertissement officiel.\n\n"
        f"Notre équipe de modération a constaté un comportement ou un contenu qui ne respecte pas "
        f"pleinement les règles de la plateforme SombaTeka.\n\n"
        f"Détail de l'avertissement :\n"
        f"{detail}\n\n"
        f"Ce que nous attendons de vous :\n"
        f"• Cesser immédiatement la pratique concernée\n"
        f"• Vérifier vos annonces, messages et interactions récentes\n"
        f"• Respecter la charte utilisateur et les lois en vigueur en RDC\n\n"
        f"En cas de récidive :\n"
        f"Des mesures plus strictes pourront être appliquées : masquage d'annonces, retrait du statut "
        f"vendeur officiel ou suspension définitive du compte.\n\n"
        f"Vous pouvez répondre à ce message pour expliquer votre point de vue ou demander des "
        f"précisions. Nous traiterons votre retour avec attention.\n\n"
        f"Merci de votre coopération pour maintenir SombaTeka sûr et fiable pour tous."
    )
    notify_user(db, user_id=user_id, notif_type="team_warning", title=title, body=body, message=message)
