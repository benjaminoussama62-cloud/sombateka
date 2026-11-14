"""Emails transactionnels utilisateur (bienvenue, commandes, paiements, rappels).

Chaque fonction envoie via `send_email` → provider configuré (Ayeba en prod,
secours Resend/SMTP). Jamais d'exception vers l'appelant : un email raté ne doit
jamais bloquer une commande ou une inscription.
"""

from __future__ import annotations

import logging

from app.models import CartItem, Listing, Order, User
from app.services.email import _html_wrapper, send_email
from app.settings import settings

logger = logging.getLogger(__name__)


def _fmt_cdf(amount: int | None) -> str:
    if amount is None:
        return "—"
    return f"{amount:,}".replace(",", " ") + " FC"


def _name(user: User) -> str:
    return (user.display_name or "").strip() or "client(e)"


def _order_ref(order: Order) -> str:
    return f"ST-{order.id:06d}"


def _cta(url: str, label: str) -> str:
    return (
        f'<p style="margin:28px 0">'
        f'<a href="{url}" style="background:#2563eb;color:#fff;padding:12px 28px;'
        f'text-decoration:none;border-radius:6px;font-weight:600">{label}</a></p>'
    )


def _send(
    user: User,
    *,
    email_type: str,
    subject: str,
    text: str,
    html_body: str,
    data: dict | None = None,
    key: str,
    require_verified: bool = False,
) -> bool:
    """Envoi transactionnel protégé. `require_verified=True` pour les rappels/
    digest (ne pas spammer des adresses déclarées non vérifiées)."""
    if not user.email:
        return False
    if require_verified and not user.email_verified:
        return False
    try:
        return send_email(
            user.email,
            subject,
            text,
            html_body=_html_wrapper(subject, html_body),
            email_type=email_type,
            template_data=data or {},
            idempotency_key=f"sombateka:{email_type}:{key}",
        )
    except Exception:
        logger.exception("Email transactionnel %s échoué (user %s)", email_type, user.id)
        return False


# ---------------------------------------------------------------------------
# Bienvenue — après vérification de l'adresse email
# ---------------------------------------------------------------------------

def send_welcome_email(user: User) -> bool:
    name = _name(user)
    url = settings.public_base_url.rstrip("/")
    subject = "Bienvenue sur SombaTeka"
    text = (
        f"Bonjour {name},\n\n"
        "Votre adresse e-mail est confirmée et votre compte SombaTeka est actif.\n\n"
        "Vous pouvez dès maintenant parcourir des milliers d'annonces, contacter "
        "les vendeurs en toute sécurité et publier vos propres articles.\n\n"
        f"— L'équipe SombaTeka\n{url}"
    )
    html = (
        f"<p>Bonjour <strong>{name}</strong>,</p>"
        "<p>Votre adresse e-mail est confirmée et votre compte SombaTeka est désormais actif.</p>"
        "<p>Vous pouvez dès maintenant :</p>"
        "<ul>"
        "<li>Parcourir des milliers d'annonces dans toute la RDC</li>"
        "<li>Contacter les vendeurs via notre messagerie sécurisée</li>"
        "<li>Publier vos propres articles en quelques minutes</li>"
        "</ul>"
        + _cta(url, "Découvrir SombaTeka")
        + "<p>Bienvenue parmi nous,<br>— L'équipe SombaTeka</p>"
    )
    return _send(
        user, email_type="welcome", subject=subject, text=text, html_body=html,
        data={"name": name}, key=f"welcome:{user.id}",
    )


# ---------------------------------------------------------------------------
# Commandes
# ---------------------------------------------------------------------------

def send_order_created_buyer(order: Order, listing: Listing, buyer: User) -> bool:
    name, ref = _name(buyer), _order_ref(order)
    amount = _fmt_cdf(order.amount_cdf)
    url = f"{settings.public_base_url.rstrip('/')}/orders"
    subject = f"Commande {ref} enregistrée"
    text = (
        f"Bonjour {name},\n\n"
        f"Votre commande {ref} pour « {listing.title} » ({amount}) a bien été enregistrée.\n\n"
        "Prochaine étape : procédez au paiement sécurisé. Les fonds sont conservés "
        "en séquestre jusqu'à confirmation de réception de l'article.\n\n"
        f"— SombaTeka\n{url}"
    )
    html = (
        f"<p>Bonjour <strong>{name}</strong>,</p>"
        f"<p>Votre commande <strong>{ref}</strong> a bien été enregistrée :</p>"
        f'<table style="border-collapse:collapse;margin:16px 0">'
        f'<tr><td style="padding:6px 16px 6px 0;color:#6b7280">Article</td>'
        f'<td style="padding:6px 0"><strong>{listing.title}</strong></td></tr>'
        f'<tr><td style="padding:6px 16px 6px 0;color:#6b7280">Montant</td>'
        f'<td style="padding:6px 0"><strong>{amount}</strong></td></tr>'
        f'<tr><td style="padding:6px 16px 6px 0;color:#6b7280">Ville</td>'
        f'<td style="padding:6px 0">{listing.city}</td></tr></table>'
        "<p><strong>Prochaine étape :</strong> procédez au paiement sécurisé. "
        "Vos fonds sont conservés en séquestre et reversés au vendeur uniquement "
        "après confirmation de réception.</p>"
        + _cta(url, "Suivre ma commande")
        + "<p>— L'équipe SombaTeka</p>"
    )
    return _send(
        buyer, email_type="notification", subject=subject, text=text, html_body=html,
        data={"order_ref": ref, "title": listing.title, "amount": order.amount_cdf},
        key=f"order_created:{order.id}",
    )


def send_new_order_seller(order: Order, listing: Listing, seller: User) -> bool:
    name, ref = _name(seller), _order_ref(order)
    amount = _fmt_cdf(order.amount_cdf)
    url = f"{settings.public_base_url.rstrip('/')}/orders"
    subject = f"Nouvelle commande {ref} — {listing.title}"
    text = (
        f"Bonjour {name},\n\n"
        f"Vous avez reçu une commande {ref} pour « {listing.title} » ({amount}).\n\n"
        "L'acheteur doit maintenant procéder au paiement sécurisé. Vous serez "
        "notifié dès que les fonds seront placés en séquestre.\n\n"
        f"— SombaTeka\n{url}"
    )
    html = (
        f"<p>Bonjour <strong>{name}</strong>,</p>"
        f"<p>Vous avez reçu une nouvelle commande <strong>{ref}</strong> :</p>"
        f'<table style="border-collapse:collapse;margin:16px 0">'
        f'<tr><td style="padding:6px 16px 6px 0;color:#6b7280">Article</td>'
        f'<td style="padding:6px 0"><strong>{listing.title}</strong></td></tr>'
        f'<tr><td style="padding:6px 16px 6px 0;color:#6b7280">Montant</td>'
        f'<td style="padding:6px 0"><strong>{amount}</strong></td></tr></table>'
        "<p>L'acheteur doit maintenant procéder au paiement sécurisé. Vous serez "
        "notifié dès que les fonds seront placés en séquestre — ne préparez "
        "l'expédition qu'à ce moment-là.</p>"
        + _cta(url, "Voir la commande")
        + "<p>— L'équipe SombaTeka</p>"
    )
    return _send(
        seller, email_type="notification", subject=subject, text=text, html_body=html,
        data={"order_ref": ref, "title": listing.title, "amount": order.amount_cdf},
        key=f"new_order_seller:{order.id}",
    )


# ---------------------------------------------------------------------------
# Paiement (séquestre) — reçu acheteur + notification vendeur
# ---------------------------------------------------------------------------

def send_payment_receipt(order: Order, listing: Listing, buyer: User) -> bool:
    """Reçu officiel : fonds sécurisés en séquestre (= 'facture' côté acheteur)."""
    name, ref = _name(buyer), _order_ref(order)
    amount = _fmt_cdf(order.amount_cdf)
    payment_ref = order.payment_reference or ref
    url = f"{settings.public_base_url.rstrip('/')}/orders"
    subject = f"Reçu de paiement {ref} — SombaTeka"
    text = (
        f"Bonjour {name},\n\n"
        f"Paiement confirmé pour la commande {ref}.\n\n"
        f"Article : {listing.title}\n"
        f"Montant : {amount}\n"
        f"Référence : {payment_ref}\n\n"
        "Vos fonds sont conservés en séquestre. Le vendeur est informé et prépare "
        "la remise de votre article. Le versement n'intervient qu'après votre "
        "confirmation de réception.\n\n"
        f"— SombaTeka\n{url}"
    )
    html = (
        f"<p>Bonjour <strong>{name}</strong>,</p>"
        "<p>Votre paiement a été confirmé. Voici votre reçu :</p>"
        f'<table style="border-collapse:collapse;margin:16px 0;border:1px solid #e5e7eb">'
        f'<tr><td style="padding:8px 16px;color:#6b7280;border-bottom:1px solid #e5e7eb">Commande</td>'
        f'<td style="padding:8px 16px;border-bottom:1px solid #e5e7eb"><strong>{ref}</strong></td></tr>'
        f'<tr><td style="padding:8px 16px;color:#6b7280;border-bottom:1px solid #e5e7eb">Article</td>'
        f'<td style="padding:8px 16px;border-bottom:1px solid #e5e7eb"><strong>{listing.title}</strong></td></tr>'
        f'<tr><td style="padding:8px 16px;color:#6b7280;border-bottom:1px solid #e5e7eb">Montant</td>'
        f'<td style="padding:8px 16px;border-bottom:1px solid #e5e7eb"><strong>{amount}</strong></td></tr>'
        f'<tr><td style="padding:8px 16px;color:#6b7280">Référence paiement</td>'
        f'<td style="padding:8px 16px">{payment_ref}</td></tr></table>'
        "<p>Vos fonds sont <strong>conservés en séquestre</strong>. Le versement au "
        "vendeur n'intervient qu'après votre confirmation de réception de l'article.</p>"
        + _cta(url, "Suivre ma commande")
        + "<p>Conservez ce reçu — il fait office de justificatif de paiement.<br>— L'équipe SombaTeka</p>"
    )
    return _send(
        buyer, email_type="receipt", subject=subject, text=text, html_body=html,
        data={
            "order_ref": ref, "title": listing.title, "amount": order.amount_cdf,
            "payment_ref": payment_ref,
        },
        key=f"receipt:{order.id}",
    )


def send_seller_payment_secured(order: Order, listing: Listing, seller: User) -> bool:
    name, ref = _name(seller), _order_ref(order)
    amount = _fmt_cdf(order.amount_cdf)
    url = f"{settings.public_base_url.rstrip('/')}/orders"
    subject = f"Paiement sécurisé — préparez la commande {ref}"
    text = (
        f"Bonjour {name},\n\n"
        f"Le paiement de {amount} pour « {listing.title} » (commande {ref}) est "
        "désormais sécurisé en séquestre.\n\n"
        "Vous pouvez procéder à la remise de l'article. Les fonds vous seront "
        "versés après confirmation de réception par l'acheteur.\n\n"
        f"— SombaTeka\n{url}"
    )
    html = (
        f"<p>Bonjour <strong>{name}</strong>,</p>"
        f"<p>Le paiement de <strong>{amount}</strong> pour <strong>« {listing.title} »</strong> "
        f"(commande {ref}) est désormais sécurisé en séquestre.</p>"
        "<p><strong>Vous pouvez procéder à la remise de l'article.</strong> Les fonds "
        "vous seront versés après confirmation de réception par l'acheteur.</p>"
        + _cta(url, "Voir la commande")
        + "<p>— L'équipe SombaTeka</p>"
    )
    return _send(
        seller, email_type="notification", subject=subject, text=text, html_body=html,
        data={"order_ref": ref, "title": listing.title, "amount": order.amount_cdf},
        key=f"seller_paid:{order.id}",
    )


# ---------------------------------------------------------------------------
# Finalisation / remboursement
# ---------------------------------------------------------------------------

def send_order_completed_buyer(order: Order, listing: Listing, buyer: User) -> bool:
    name, ref = _name(buyer), _order_ref(order)
    url = f"{settings.public_base_url.rstrip('/')}/orders"
    subject = f"Commande {ref} finalisée — merci"
    text = (
        f"Bonjour {name},\n\n"
        f"Votre commande {ref} pour « {listing.title} » est finalisée. "
        "Les fonds ont été reversés au vendeur.\n\n"
        "Merci de votre confiance. N'hésitez pas à laisser un avis pour aider "
        "la communauté SombaTeka.\n\n"
        f"— SombaTeka\n{url}"
    )
    html = (
        f"<p>Bonjour <strong>{name}</strong>,</p>"
        f"<p>Votre commande <strong>{ref}</strong> pour « {listing.title} » est finalisée. "
        "Les fonds ont été reversés au vendeur.</p>"
        "<p>Merci de votre confiance — pensez à laisser un avis pour aider la communauté.</p>"
        + _cta(url, "Voir mes commandes")
        + "<p>— L'équipe SombaTeka</p>"
    )
    return _send(
        buyer, email_type="notification", subject=subject, text=text, html_body=html,
        data={"order_ref": ref, "title": listing.title}, key=f"completed_b:{order.id}",
    )


def send_order_completed_seller(order: Order, listing: Listing, seller: User, *, amount_cdf: int | None = None) -> bool:
    name, ref = _name(seller), _order_ref(order)
    amount = _fmt_cdf(amount_cdf if amount_cdf is not None else order.amount_cdf)
    url = f"{settings.public_base_url.rstrip('/')}/wallet"
    subject = f"Vente finalisée {ref} — versement programmé"
    text = (
        f"Bonjour {name},\n\n"
        f"Votre vente « {listing.title} » (commande {ref}) est finalisée. "
        f"Un versement de {amount} est programmé vers votre compte.\n\n"
        f"— SombaTeka\n{url}"
    )
    html = (
        f"<p>Bonjour <strong>{name}</strong>,</p>"
        f"<p>Votre vente <strong>« {listing.title} »</strong> (commande {ref}) est finalisée. "
        f"Un versement de <strong>{amount}</strong> est programmé vers votre compte.</p>"
        + _cta(url, "Voir mon portefeuille")
        + "<p>— L'équipe SombaTeka</p>"
    )
    return _send(
        seller, email_type="notification", subject=subject, text=text, html_body=html,
        data={"order_ref": ref, "title": listing.title, "amount": amount_cdf},
        key=f"completed_s:{order.id}",
    )


def send_order_refunded(order: Order, listing: Listing, buyer: User) -> bool:
    name, ref = _name(buyer), _order_ref(order)
    amount = _fmt_cdf(order.amount_cdf)
    url = f"{settings.public_base_url.rstrip('/')}/orders"
    subject = f"Remboursement {ref} — {amount}"
    text = (
        f"Bonjour {name},\n\n"
        f"Votre commande {ref} pour « {listing.title} » a été remboursée.\n\n"
        f"Montant : {amount}\n"
        "Le remboursement est effectué via votre moyen de paiement d'origine "
        "(délai selon l'opérateur).\n\n"
        f"— SombaTeka\n{url}"
    )
    html = (
        f"<p>Bonjour <strong>{name}</strong>,</p>"
        f"<p>Votre commande <strong>{ref}</strong> pour « {listing.title} » a été remboursée.</p>"
        f"<p>Montant : <strong>{amount}</strong><br>"
        "Le remboursement est effectué via votre moyen de paiement d'origine "
        "(le délai dépend de votre opérateur).</p>"
        + _cta(url, "Voir mes commandes")
        + "<p>— L'équipe SombaTeka</p>"
    )
    return _send(
        buyer, email_type="notification", subject=subject, text=text, html_body=html,
        data={"order_ref": ref, "title": listing.title, "amount": order.amount_cdf},
        key=f"refund:{order.id}",
    )


# ---------------------------------------------------------------------------
# Rappels (adresses vérifiées uniquement)
# ---------------------------------------------------------------------------

def send_unread_messages_reminder(user: User, *, count: int, senders: list[str]) -> bool:
    name = _name(user)
    url = f"{settings.public_base_url.rstrip('/')}/messages"
    who = ", ".join(senders[:3]) + ("…" if len(senders) > 3 else "")
    plural = "s" if count > 1 else ""
    subject = f"{count} message{plural} non lu{plural} vous attend{plural}"
    text = (
        f"Bonjour {name},\n\n"
        f"Vous avez {count} message{plural} non lu{plural} de la part de {who}.\n\n"
        "Répondez vite — une réponse rapide fait la différence sur une marketplace.\n\n"
        f"— SombaTeka\n{url}"
    )
    html = (
        f"<p>Bonjour <strong>{name}</strong>,</p>"
        f"<p>Vous avez <strong>{count} message{plural} non lu{plural}</strong> "
        f"de la part de {who}.</p>"
        "<p>Une réponse rapide fait souvent la différence entre une vente conclue et une occasion manquée.</p>"
        + _cta(url, "Lire mes messages")
        + "<p>— L'équipe SombaTeka</p>"
    )
    return _send(
        user, email_type="notification", subject=subject, text=text, html_body=html,
        data={"count": count, "senders": senders}, key=f"msgrem:{user.id}",
        require_verified=True,
    )


def send_cart_reminder(user: User, *, items: list[CartItem]) -> bool:
    name = _name(user)
    url = f"{settings.public_base_url.rstrip('/')}/cart"
    titles = [i.listing.title for i in items if i.listing][:3]
    total = sum((i.listing.price_cdf or 0) * i.quantity for i in items if i.listing)
    count = len(items)
    subject = "Votre panier vous attend"
    text = (
        f"Bonjour {name},\n\n"
        f"{count} article(s) vous attendent dans votre panier : "
        f"{', '.join(titles)}{'…' if count > 3 else ''}.\n\n"
        f"Total estimé : {_fmt_cdf(total)}\n\n"
        "Les articles populaires partent vite — finalisez votre commande.\n\n"
        f"— SombaTeka\n{url}"
    )
    html = (
        f"<p>Bonjour <strong>{name}</strong>,</p>"
        f"<p><strong>{count} article(s)</strong> vous attendent dans votre panier :</p>"
        "<ul>" + "".join(f"<li>{t}</li>" for t in titles) + ("<li>…</li>" if count > 3 else "") + "</ul>"
        f"<p>Total estimé : <strong>{_fmt_cdf(total)}</strong></p>"
        "<p>Les articles populaires partent vite — ne les laissez pas passer.</p>"
        + _cta(url, "Finaliser ma commande")
        + "<p>— L'équipe SombaTeka</p>"
    )
    return _send(
        user, email_type="notification", subject=subject, text=text, html_body=html,
        data={"count": count, "titles": titles, "total": total}, key=f"cart:{user.id}",
        require_verified=True,
    )


def send_weekly_digest(user: User, *, new_count: int, sample_titles: list[str]) -> bool:
    """Nouveautés de la semaine (uniquement adresses vérifiées)."""
    if new_count <= 0:
        return False
    name = _name(user)
    url = settings.public_base_url.rstrip("/")
    subject = f"{new_count} nouvelles annonces cette semaine"
    text = (
        f"Bonjour {name},\n\n"
        f"{new_count} nouvelles annonces ont été publiées sur SombaTeka cette semaine.\n\n"
        f"À la une : {', '.join(sample_titles[:3])}\n\n"
        f"— SombaTeka\n{url}"
    )
    html = (
        f"<p>Bonjour <strong>{name}</strong>,</p>"
        f"<p><strong>{new_count} nouvelles annonces</strong> ont été publiées sur "
        "SombaTeka cette semaine.</p>"
        "<p>À la une :</p><ul>"
        + "".join(f"<li>{t}</li>" for t in sample_titles[:3])
        + "</ul>"
        + _cta(url, "Voir les nouveautés")
        + "<p>— L'équipe SombaTeka</p>"
    )
    return _send(
        user, email_type="notification", subject=subject, text=text, html_body=html,
        data={"count": new_count, "titles": sample_titles}, key=f"digest:{user.id}",
        require_verified=True,
    )
