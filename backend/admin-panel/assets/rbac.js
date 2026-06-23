/** Permissions alignées sur backend/app/admin_rbac.py */
export const PERM = {
  DASHBOARD: "dashboard.view",
  KYC_VIEW: "kyc.view",
  KYC_WRITE: "kyc.write",
  REPORTS_VIEW: "reports.view",
  REPORTS_WRITE: "reports.write",
  LISTINGS_VIEW: "listings.view",
  LISTINGS_MODERATE: "listings.moderate",
  USERS_VIEW: "users.view",
  USERS_PII: "users.pii_reveal",
  USERS_BAN: "users.ban",
  USERS_REVOKE: "users.revoke_official",
  AUDIT_VIEW: "audit.view",
  TEAM_VIEW: "team.view",
  TEAM_MANAGE: "team.manage",
  ESCROW_VIEW: "escrow.view",
  ESCROW_RESOLVE: "escrow.resolve",
  SUPPORT_VIEW: "support.view",
  SUPPORT_REPLY: "support.reply",
  TRASH_VIEW: "trash.view",
  TRASH_MANAGE: "trash.manage",
  CHAT_VIEW: "chat.view",
  CHAT_SEND: "chat.send",
  CHAT_CREATE_GROUP: "chat.create_group",
};

export const STAFF_ROLES = ["super_admin", "admin", "moderator"];

const STAFF_SET = new Set(STAFF_ROLES);

export function isStaffRole(role) {
  return STAFF_SET.has(role);
}

export function hasPerm(me, permission) {
  if (!me?.permissions) return false;
  return me.permissions.includes(permission);
}

export function canBan(me) {
  return hasPerm(me, PERM.USERS_BAN);
}

export function canRevealPii(me) {
  return hasPerm(me, PERM.USERS_PII);
}

export function canManageTeam(me) {
  return me?.role === "super_admin" || hasPerm(me, PERM.TEAM_MANAGE);
}

export function canManageTrash(me) {
  return me?.role === "super_admin" && hasPerm(me, PERM.TRASH_MANAGE);
}

export function canCreateChatGroup(me) {
  return me?.role === "super_admin" && hasPerm(me, PERM.CHAT_CREATE_GROUP);
}
