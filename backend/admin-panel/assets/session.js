/** Session admin partagée entre login et dashboard. */
import { isStaffRole } from "./rbac.js";

export const TOKEN_KEY = "st_admin_token";
export const TOKEN_EXP_KEY = "st_admin_exp";
export const ME_KEY = "st_admin_me";

export function getToken() {
  const exp = sessionStorage.getItem(TOKEN_EXP_KEY);
  if (exp && Date.now() > Number(exp)) {
    clearSession();
    return null;
  }
  return sessionStorage.getItem(TOKEN_KEY);
}

export function setSession(token, me, sessionMinutes) {
  sessionStorage.setItem(TOKEN_KEY, token);
  const mins = sessionMinutes ?? remainingMinutes();
  sessionStorage.setItem(TOKEN_EXP_KEY, String(Date.now() + mins * 60 * 1000));
  sessionStorage.setItem(ME_KEY, JSON.stringify(me));
}

function remainingMinutes() {
  const exp = sessionStorage.getItem(TOKEN_EXP_KEY);
  if (!exp) return 480;
  const ms = Number(exp) - Date.now();
  return Math.max(1, Math.ceil(ms / 60000));
}

export function clearSession() {
  sessionStorage.removeItem(TOKEN_KEY);
  sessionStorage.removeItem(TOKEN_EXP_KEY);
  sessionStorage.removeItem(ME_KEY);
}

export function getMe() {
  try {
    return JSON.parse(sessionStorage.getItem(ME_KEY) || "null");
  } catch {
    return null;
  }
}

export function isAuthenticated() {
  const me = getMe();
  return Boolean(getToken() && me && isStaffRole(me.role));
}

export function updateMe(patch) {
  const cur = getMe();
  const token = getToken();
  if (!cur || !token) return;
  setSession(token, { ...cur, ...patch }, remainingMinutes());
}
