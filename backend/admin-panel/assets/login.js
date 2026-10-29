import { setSession, isAuthenticated } from "./session.js";

const API = `${window.location.origin}/api`;
const $ = (s) => document.querySelector(s);

let challengeToken = null;
let loginMode = "password"; // password | verify | setup

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

function showError(msg) {
  const err = $("#login-error");
  err.textContent = msg || "Erreur";
  err.hidden = false;
}

function enter2faStep(status, data) {
  challengeToken = data.challenge_token;
  loginMode = status === "needs_2fa_setup" ? "setup" : "verify";
  $("#step-credentials").hidden = true;
  $("#step-password-wrap").hidden = true;
  $("#login-phone").required = false;
  $("#login-password").required = false;
  $("#step-2fa").hidden = false;
  $("#login-totp").required = true;
  $("#login-totp").focus();

  if (loginMode === "setup") {
    $("#login-title").textContent = "Activer le 2FA";
    $("#login-subtitle").textContent =
      data.message || "Scannez le QR puis entrez le code à 6 chiffres.";
    $("#setup-block").hidden = false;
    $("#totp-secret").textContent = data.totp_secret || "";
    const qrHost = $("#qrcode");
    qrHost.innerHTML = "";
    const img = document.createElement("img");
    img.alt = "QR code 2FA SombaTeka Admin";
    img.width = 200;
    img.height = 200;
    img.style.display = "block";
    if (data.qr_data_url) {
      img.src = data.qr_data_url;
    } else if (data.otpauth_uri) {
      img.src =
        "https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=" +
        encodeURIComponent(data.otpauth_uri);
    }
    qrHost.appendChild(img);
  } else {
    $("#login-title").textContent = "Vérification 2FA";
    $("#login-subtitle").textContent =
      data.message || "Entrez le code de votre application Authenticator.";
    $("#setup-block").hidden = true;
  }
  $("#login-submit").textContent = "Valider le code";
}

async function finishSession(accessToken) {
  const meRes = await fetch(`${API}/admin/me`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  const meData = await meRes.json();
  if (!meRes.ok) throw new Error(meData.detail || "Session invalide");
  const cfgRes = await fetch(`${window.location.origin}/admin/bootstrap-config`);
  const cfg = cfgRes.ok ? await cfgRes.json() : { session_minutes: 480 };
  setSession(
    accessToken,
    {
      ...meData.user,
      permissions: meData.permissions,
    },
    cfg.session_minutes || 480,
  );
  window.location.replace("/admin/dashboard");
}

$("#login-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const err = $("#login-error");
  const btn = $("#login-submit");
  const honeypot = $("#login-website")?.value?.trim();
  if (honeypot) {
    showError("Identifiants invalides");
    return;
  }
  err.hidden = true;
  btn.disabled = true;
  const prevLabel = btn.textContent;
  btn.textContent = "…";

  try {
    if (loginMode === "password") {
      const phone = $("#login-phone").value.trim();
      const password = $("#login-password").value;
      const loginRes = await fetch(`${API}/auth/admin/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "same-origin",
        body: JSON.stringify({ phone_e164: phone, password }),
      });
      const loginData = await loginRes.json().catch(() => ({}));
      if (!loginRes.ok) {
        const detail = loginData.detail;
        throw new Error(typeof detail === "string" ? detail : "Identifiants invalides");
      }
      if (loginData.status === "ok" && loginData.access_token) {
        await finishSession(loginData.access_token);
        return;
      }
      if (loginData.status === "needs_2fa" || loginData.status === "needs_2fa_setup") {
        enter2faStep(loginData.status, loginData);
        return;
      }
      throw new Error("Réponse login inattendue");
    }

    // verify or setup
    const code = ($("#login-totp").value || "").trim();
    if (!/^\d{6}$/.test(code)) {
      throw new Error("Entrez un code à 6 chiffres");
    }
    const path =
      loginMode === "setup" ? "/auth/admin/2fa/confirm-setup" : "/auth/admin/2fa/verify";
    const res = await fetch(`${API}${path}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "same-origin",
      body: JSON.stringify({ challenge_token: challengeToken, code }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      const detail = data.detail;
      throw new Error(typeof detail === "string" ? detail : "Code 2FA invalide");
    }
    if (data.status !== "ok" || !data.access_token) {
      throw new Error("Échec de la vérification 2FA");
    }
    await finishSession(data.access_token);
  } catch (ex) {
    showError(ex.message || "Erreur de connexion");
  } finally {
    btn.disabled = false;
    if (loginMode === "password") btn.textContent = "Se connecter";
    else btn.textContent = prevLabel.includes("Valider") ? prevLabel : "Valider le code";
  }
});
