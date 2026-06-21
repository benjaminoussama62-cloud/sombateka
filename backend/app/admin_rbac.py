"""Contrôle d'accès panneau admin (moindre privilège)."""

from __future__ import annotations

from app.models import UserRole

# Permissions granulaires
PERM_DASHBOARD = "dashboard.view"
PERM_KYC_VIEW = "kyc.view"
PERM_KYC_WRITE = "kyc.write"
PERM_REPORTS_VIEW = "reports.view"
PERM_REPORTS_WRITE = "reports.write"
PERM_LISTINGS_VIEW = "listings.view"
PERM_LISTINGS_MODERATE = "listings.moderate"
PERM_USERS_VIEW = "users.view"
PERM_USERS_PII = "users.pii_reveal"
PERM_USERS_BAN = "users.ban"
PERM_USERS_REVOKE_OFFICIAL = "users.revoke_official"
PERM_AUDIT_VIEW = "audit.view"
PERM_TEAM_VIEW = "team.view"
PERM_TEAM_MANAGE = "team.manage"
PERM_ESCROW_VIEW = "escrow.view"
PERM_ESCROW_RESOLVE = "escrow.resolve"
PERM_SUPPORT_VIEW = "support.view"
PERM_SUPPORT_REPLY = "support.reply"

ROLE_LABELS: dict[UserRole, str] = {
    UserRole.super_admin: "Super administrateur",
    UserRole.admin: "Administrateur",
    UserRole.moderator: "Modérateur",
}

ROLE_PERMISSIONS: dict[UserRole, frozenset[str]] = {
  UserRole.moderator: frozenset(
        {
            PERM_DASHBOARD,
            PERM_REPORTS_VIEW,
            PERM_REPORTS_WRITE,
            PERM_LISTINGS_VIEW,
            PERM_LISTINGS_MODERATE,
            PERM_ESCROW_VIEW,
            PERM_SUPPORT_VIEW,
            PERM_SUPPORT_REPLY,
        }
    ),
    UserRole.admin: frozenset(
        {
            PERM_DASHBOARD,
            PERM_KYC_VIEW,
            PERM_KYC_WRITE,
            PERM_REPORTS_VIEW,
            PERM_REPORTS_WRITE,
            PERM_LISTINGS_VIEW,
            PERM_LISTINGS_MODERATE,
            PERM_USERS_VIEW,
            PERM_USERS_PII,
            PERM_USERS_REVOKE_OFFICIAL,
            PERM_ESCROW_VIEW,
            PERM_ESCROW_RESOLVE,
            PERM_SUPPORT_VIEW,
            PERM_SUPPORT_REPLY,
        }
    ),
    UserRole.super_admin: frozenset(
        {
            PERM_DASHBOARD,
            PERM_KYC_VIEW,
            PERM_KYC_WRITE,
            PERM_REPORTS_VIEW,
            PERM_REPORTS_WRITE,
            PERM_LISTINGS_VIEW,
            PERM_LISTINGS_MODERATE,
            PERM_USERS_VIEW,
            PERM_USERS_PII,
            PERM_USERS_BAN,
            PERM_USERS_REVOKE_OFFICIAL,
            PERM_AUDIT_VIEW,
            PERM_TEAM_VIEW,
            PERM_TEAM_MANAGE,
            PERM_ESCROW_VIEW,
            PERM_ESCROW_RESOLVE,
            PERM_SUPPORT_VIEW,
            PERM_SUPPORT_REPLY,
        }
    ),
}

STAFF_ROLES = frozenset({UserRole.super_admin, UserRole.admin, UserRole.moderator})


def is_staff(role: UserRole) -> bool:
    return role in STAFF_ROLES


def permissions_for(role: UserRole) -> list[str]:
    return sorted(ROLE_PERMISSIONS.get(role, frozenset()))


def has_permission(role: UserRole, permission: str) -> bool:
    return permission in ROLE_PERMISSIONS.get(role, frozenset())
