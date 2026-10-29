"""Identifiants téléphone internes vs numéros réels utilisateur."""

# Préfixes réservés (non assignables en OTP public).
SYNTHETIC_PREFIXES = ("+888", "+999")


def is_synthetic_phone(phone: str | None) -> bool:
    if not phone:
        return True
    return phone.startswith(SYNTHETIC_PREFIXES)


def public_phone(user) -> str | None:
    """Numéro affiché côté client — null tant qu'aucun vrai numéro n'est vérifié."""
    phone = getattr(user, "phone_e164", None)
    if not phone or is_synthetic_phone(phone):
        return None
    if not getattr(user, "is_phone_verified", False):
        return None
    return phone


def user_needs_phone(user) -> bool:
    return is_synthetic_phone(getattr(user, "phone_e164", None)) or not getattr(
        user, "is_phone_verified", False
    )


def user_needs_password(user) -> bool:
    return not bool(getattr(user, "password_hash", None))


def user_needs_account_setup(user) -> bool:
    return user_needs_phone(user) or user_needs_password(user)
