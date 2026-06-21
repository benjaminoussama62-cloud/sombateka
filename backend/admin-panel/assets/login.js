import { setSession, isAuthenticated } from "./session.js";

const API = `${window.location.origin}/api`;
const $ = (s) => document.querySelector(s);

if (isAuthenticated()) {
  window.location.replace("/admin/dashboard");
}

$("#toggle-password")?.addEventListener("click", () => {
  const input = $("#login-password");
  const btn = $("#toggle-password");
  const show = input.type === "password";
  input.type = show ? "text" : "password";
  btn.textContent = show ? "Masquer" : "Voir";
  btn.setAttribute("aria-label", show ? "Masquer le mot de passe" : "Afficher le mot de passe");
});

$("#login-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const err = $("#login-error");
  const btn = $("#login-submit");
  err.hidden = true;
  btn.disabled = true;
  btn.textContent = "Connexion…";
  try {
    const phone = $("#login-phone").value.trim();
    const password = $("#login-password").value;
    const loginRes = await fetch(`${API}/auth/admin/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ phone_e164: phone, password }),
    });
    const loginData = await loginRes.json().catch(() => ({}));
    if (!loginRes.ok) {
      throw new Error(loginData.detail || "Identifiants invalides");
    }
    const meRes = await fetch(`${API}/admin/me`, {
      headers: { Authorization: `Bearer ${loginData.access_token}` },
    });
    const meData = await meRes.json();
    if (!meRes.ok) throw new Error(meData.detail || "Session invalide");
    const cfgRes = await fetch(`${window.location.origin}/admin/bootstrap-config`);
    const cfg = cfgRes.ok ? await cfgRes.json() : { session_minutes: 480 };
    setSession(
      loginData.access_token,
      {
        ...meData.user,
        permissions: meData.permissions,
      },
      cfg.session_minutes || 480,
    );
    window.location.replace("/admin/dashboard");
  } catch (ex) {
    err.textContent = ex.message || "Erreur de connexion";
    err.hidden = false;
  } finally {
    btn.disabled = false;
    btn.textContent = "Se connecter";
  }
});
