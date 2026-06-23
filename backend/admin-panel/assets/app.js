/** SombaTeka Admin */
import {
  getToken,
  getMe,
  clearSession,
  isAuthenticated,
  updateMe,
} from "./session.js";
import {
  PERM,
  STAFF_ROLES,
  hasPerm,
  canBan,
  canRevealPii,
  canManageTeam,
  canManageTrash,
  isStaffRole,
} from "./rbac.js";

const API = `${window.location.origin}/api`;

const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];

const PAGES = {
  dashboard: { title: "Tableau de bord" },
  support: { title: "Centre d'aide" },
  kyc: { title: "Comptes pro" },
  reports: { title: "Signalements" },
  escrow: { title: "Litiges & séquestre" },
  users: { title: "Utilisateurs" },
  listings: { title: "Annonces" },
  audit: { title: "Journal d'audit" },
  team: { title: "Équipe" },
  trash: { title: "Corbeille serveur" },
};

let currentPage = "dashboard";
let statsCache = null;
let kycTab = "pending";

function toast(msg, isError = false) {
  const el = $("#toast");
  el.textContent = msg;
  el.className = isError ? "toast error" : "toast";
  el.hidden = false;
  clearTimeout(toast._t);
  toast._t = setTimeout(() => { el.hidden = true; }, 4500);
}

function escapeHtml(s) {
  if (s == null) return "";
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function formatDate(iso) {
  if (!iso) return "—";
  try {
    return new Date(iso).toLocaleString("fr-FR", { dateStyle: "short", timeStyle: "short" });
  } catch {
    return iso;
  }
}

function formatPrice(cdf) {
  if (cdf == null) return "—";
  return `${Number(cdf).toLocaleString("fr-FR")} CDF`;
}

function badge(status) {
  const cls = (status || "").replace(/\s/g, "-").toLowerCase();
  return `<span class="badge badge-${cls}">${escapeHtml(status)}</span>`;
}

function auditActionLabel(action) {
  const labels = {
    "users.pii_reveal": "Révélation téléphone client",
    "user.ban": "Bannissement",
    "user.unban": "Débannissement",
    "user.revoke_official": "Révocation vendeur pro",
    "kyc.approve": "KYC approuvé",
    "kyc.reject": "KYC refusé",
    "report.resolve": "Signalement clôturé",
    "report.reviewing": "Signalement en cours",
    "report.hide_listing": "Annonce masquée (signalement)",
    "listing.hide": "Annonce masquée",
    "listing.restore": "Annonce rétablie",
    "team.role_change": "Changement de rôle staff",
    "team.revoke_access": "Accès staff révoqué",
    "team.invite": "Invitation membre staff",
    "team.password_reset": "Réinitialisation mot de passe staff",
    "support.reply": "Réponse centre d'aide",
    "escrow.refund_buyer": "Remboursement acheteur",
    "user.warn": "Avertissement utilisateur",
  };
  return labels[action] || action;
}

async function api(path, options = {}) {
  const headers = { "Content-Type": "application/json", ...(options.headers || {}) };
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${API}${path}`, { ...options, headers });
  const text = await res.text();
  let data = null;
  if (text) {
    try { data = JSON.parse(text); } catch { data = { detail: text }; }
  }
  if (!res.ok) {
    const d = data?.detail;
    const msg = typeof d === "string" ? d : Array.isArray(d) ? d.map((x) => x.msg || x).join(", ") : `Erreur ${res.status}`;
    const err = new Error(msg);
    err.status = res.status;
    throw err;
  }
  return data;
}

function setLoading(on) {
  const loader = $("#page-loading");
  if (loader) loader.hidden = !on;
  const content = $("#page-content");
  if (content) content.style.opacity = on ? "0.6" : "1";
}

function openModal(title, bodyHtml, actionsHtml = "", { wide = false } = {}) {
  $("#modal-title").textContent = title;
  $("#modal-body").innerHTML = bodyHtml;
  $("#modal-actions").innerHTML = actionsHtml;
  $("#modal").classList.toggle("modal-wide", wide);
  $("#modal").showModal();
}

function closeModal() {
  $("#modal").close();
}

function applyNavPermissions() {
  const me = getMe();
  $$(".nav-item[data-perm]").forEach((btn) => {
    const perm = btn.dataset.perm;
    const allowed = !perm || hasPerm(me, perm);
    btn.hidden = !allowed;
  });
  ["ops", "gov"].forEach((section) => {
    const label = $(`.nav-section[data-nav-section="${section}"]`);
    if (!label) return;
    let next = label.nextElementSibling;
    let anyVisible = false;
    while (next && !next.classList.contains("nav-section")) {
      if (next.classList.contains("nav-item") && !next.hidden) anyVisible = true;
      next = next.nextElementSibling;
    }
    label.hidden = !anyVisible;
  });
}

function firstAllowedPage() {
  const order = ["dashboard", "support", "reports", "listings", "kyc", "users", "audit", "team", "trash"];
  const me = getMe();
  for (const p of order) {
    const perm = $(`.nav-item[data-page="${p}"]`)?.dataset?.perm;
    if (!perm || hasPerm(me, perm)) return p;
  }
  return "dashboard";
}

async function refreshStats() {
  if (!hasPerm(getMe(), PERM.DASHBOARD)) return null;
  statsCache = await api("/admin/stats");
  $$("[data-badge]").forEach((el) => {
    const key = el.dataset.badge;
    const v = statsCache[key];
    if (v > 0) {
      el.textContent = v > 99 ? "99+" : v;
      el.hidden = false;
    } else {
      el.hidden = true;
    }
  });
  return statsCache;
}

function navigate(page) {
  const me = getMe();
  const btn = $(`.nav-item[data-page="${page}"]`);
  const perm = btn?.dataset?.perm;
  if (perm && !hasPerm(me, perm)) {
    toast("Accès refusé pour votre rôle.", true);
    return;
  }
  currentPage = page;
  const meta = PAGES[page] || { title: page };
  $("#page-title").textContent = meta.title;
  $$(".nav-item").forEach((b) => b.classList.toggle("active", b.dataset.page === page));
  $$(".page").forEach((p) => p.classList.remove("active"));
  $(`#page-${page}`)?.classList.add("active");
  loadPage(page);
}

async function loadPage(page) {
  setLoading(true);
  try {
    if (hasPerm(getMe(), PERM.DASHBOARD)) await refreshStats();
    if (page === "dashboard") {
      await renderDashboard();
    } else if (page === "support") await renderSupport();
    else if (page === "kyc") await renderKyc();
    else if (page === "reports") await renderReports();
    else if (page === "escrow") await renderEscrow();
    else if (page === "users") await renderUsers();
    else if (page === "listings") await renderListings();
    else if (page === "audit") await renderAudit();
    else if (page === "team") await renderTeam();
    else if (page === "trash") await renderTrash();
  } catch (e) {
    toast(e.message, true);
    if (e.status === 401 || e.status === 403) logout();
  } finally {
    setLoading(false);
  }
}

function logout() {
  clearSession();
  window.location.replace("/admin/login");
}

function updateIdentity() {
  const me = getMe();
  if (!me) return;
  const roleLabel = me.role_label || me.role;
  $("#admin-identity").innerHTML = `
    <strong>${escapeHtml(me.display_name || me.phone_e164)}</strong><br>
    <span class="role-chip">${escapeHtml(roleLabel)}</span>
  `;
}

async function renderDashboard() {
  const me = getMe();
  const s = statsCache || {};
  const el = $("#page-dashboard");
  const cards = [];
  if (hasPerm(me, PERM.USERS_VIEW)) {
    cards.push(statCard("Utilisateurs", s.users_total, "users"));
    cards.push(statCard("Comptes bannis", s.users_banned, "users"));
  }
  if (hasPerm(me, PERM.KYC_VIEW)) {
    cards.push(statCard("Vendeurs officiels", s.official_sellers, "kyc", false));
    cards.push(statCard("KYC en attente", s.kyc_pending, "kyc", s.kyc_pending > 0));
  }
  if (hasPerm(me, PERM.REPORTS_VIEW)) {
    cards.push(statCard("Signalements", s.reports_open, "reports", s.reports_open > 0));
  }
  if (hasPerm(me, PERM.LISTINGS_VIEW)) {
    cards.push(statCard("Annonces actives", s.listings_active, "listings", false));
    cards.push(statCard("Annonces masquées", s.listings_hidden, "listings", false));
    if (s.moderation_queue > 0) {
      cards.push(statCard("File modération auto", s.moderation_queue, "listings", true));
    }
  }
  if (hasPerm(me, PERM.SUPPORT_VIEW)) {
    cards.push(statCard("Messages aide", s.support_unread, "support", s.support_unread > 0));
  }
  if (hasPerm(me, PERM.ESCROW_VIEW)) {
    cards.push(statCard("Séquestres ouverts", s.escrow_open, "escrow", s.escrow_open > 0));
  }
  el.innerHTML = `
    ${cards.length ? `<div class="stats-grid">${cards.join("")}</div>` : ""}
    <div class="panel">
      <div class="panel-head">Activité récente</div>
      <ul class="activity-list" id="activity-list"><li class="empty">Chargement…</li></ul>
    </div>
  `;
  el.querySelectorAll(".stat-card").forEach((card) => {
    card.addEventListener("click", () => navigate(card.dataset.goto));
  });
  await loadDashboardActivity();
}

async function loadDashboardActivity() {
  const list = $("#activity-list");
  if (!list) return;
  try {
    const { items } = await api("/admin/activity");
    if (!items.length) {
      list.innerHTML = "<li class='empty'>Aucune activité récente.</li>";
      return;
    }
    list.innerHTML = items.map((a) => `
      <li>
        <div class="activity-icon ${a.type}">${a.type === "kyc" ? "📋" : a.type === "report" ? "⚠" : "👤"}</div>
        <div>
          <strong>${escapeHtml(a.title)}</strong>
          <div class="card-meta">${escapeHtml(a.subtitle)} · ${formatDate(a.at)} ${badge(a.status)}</div>
        </div>
      </li>
    `).join("");
  } catch {
    list.innerHTML = "<li class='empty'>Activité indisponible pour le moment.</li>";
  }
}

function statCard(label, value, goto, warn = false) {
  const me = getMe();
  const btn = $(`.nav-item[data-page="${goto}"]`);
  if (btn?.dataset?.perm && !hasPerm(me, btn.dataset.perm)) return "";
  return `<div class="stat-card ${warn ? "warn" : ""}" data-goto="${goto}">
    <div class="label">${label}</div>
    <div class="value">${value ?? 0}</div>
  </div>`;
}

async function renderKyc() {
  const el = $("#page-kyc");
  const canWrite = hasPerm(getMe(), PERM.KYC_WRITE);
  el.innerHTML = `
    <div class="panel">
      <div class="tabs" id="kyc-tabs">
        <button type="button" class="tab ${kycTab === "pending" ? "active" : ""}" data-status="pending">En attente</button>
        <button type="button" class="tab ${kycTab === "approved" ? "active" : ""}" data-status="approved">Approuvées</button>
        <button type="button" class="tab ${kycTab === "rejected" ? "active" : ""}" data-status="rejected">Refusées</button>
      </div>
      <div class="card-list" id="kyc-list"></div>
    </div>
  `;
  $$("#kyc-tabs .tab").forEach((tab) => {
    tab.addEventListener("click", () => { kycTab = tab.dataset.status; renderKyc(); });
  });
  const { items } = await api(`/admin/kyc?status=${kycTab}`);
  const list = $("#kyc-list");
  if (!items.length) {
    list.innerHTML = '<div class="empty">Aucune demande dans cette catégorie.</div>';
    return;
  }
  list.innerHTML = items.map((k) => `
    <div class="card-row">
      <div class="card-meta">
        <h4>${escapeHtml(k.business_name)} ${badge(k.status)}</h4>
        <div>Catégorie : ${escapeHtml(k.category || k.business_type || "—")}</div>
        <div>RCCM : ${escapeHtml(k.rccm || "—")} · NIF : ${escapeHtml(k.tax_id || "—")}</div>
        <div>Utilisateur #${k.user_id} · <span class="pii-masked">${escapeHtml(k.user_phone || "—")}</span></div>
        <div>Demandé le ${formatDate(k.created_at)} · ${k.document_count || 0} document(s)</div>
        ${k.reviewer_note ? `<div style="margin-top:6px;color:#b91c1c">Motif refus : ${escapeHtml(k.reviewer_note)}</div>` : ""}
      </div>
      <div class="card-actions">
        <button type="button" class="btn btn-primary btn-sm" data-kyc="${k.id}">Ouvrir le dossier</button>
        ${hasPerm(getMe(), PERM.USERS_VIEW) ? `<button type="button" class="btn btn-ghost btn-sm" data-user="${k.user_id}">Utilisateur</button>` : ""}
      </div>
    </div>
  `).join("");

  list.querySelectorAll("[data-kyc]").forEach((btn) => {
    btn.addEventListener("click", () => showKycDetail(Number(btn.dataset.kyc)));
  });
  list.querySelectorAll("[data-user]").forEach((btn) => {
    btn.addEventListener("click", () => showUserDetail(Number(btn.dataset.user)));
  });
}

function kycDocThumb(url, label) {
  const isPdf = (url || "").toLowerCase().includes(".pdf");
  const inner = isPdf
    ? `<div style="height:110px;display:flex;align-items:center;justify-content:center;background:#f1f5f9;font-weight:700">PDF</div>`
    : `<img src="${escapeHtml(url)}" alt="${escapeHtml(label)}" loading="lazy" />`;
  return `<div class="kyc-doc-card"><a href="${escapeHtml(url)}" target="_blank" rel="noopener">${inner}<div class="doc-meta"><strong>${escapeHtml(label)}</strong><span>Ouvrir</span></div></a></div>`;
}

async function showKycDetail(applicationId) {
  const me = getMe();
  const canWrite = hasPerm(me, PERM.KYC_WRITE);
  const data = await api(`/admin/kyc/${applicationId}`);
  const app = data.application;
  const user = data.user;
  const cl = data.checklist || {};

  const checklistHtml = `
    <ul class="kyc-checklist">
      <li class="${cl.has_rccm_number ? "ok" : "miss"}">${cl.has_rccm_number ? "✓" : "○"} Numéro RCCM renseigné</li>
      <li class="${cl.has_tax_id ? "ok" : "miss"}">${cl.has_tax_id ? "✓" : "○"} NIF renseigné</li>
      <li class="${cl.has_rccm_document ? "ok" : "miss"}">${cl.has_rccm_document ? "✓" : "○"} Scan RCCM</li>
      <li class="${cl.has_id_document ? "ok" : "miss"}">${cl.has_id_document ? "✓" : "○"} Pièce d'identité</li>
      <li class="${cl.documents_complete ? "ok" : "miss"}">${cl.documents_complete ? "✓" : "○"} Dossier documentaire minimal</li>
    </ul>`;

  const docsHtml = (app.documents || []).length
    ? `<div class="kyc-doc-grid">${(app.documents || []).map((d) => kycDocThumb(d.url, d.label)).join("")}</div>`
    : `<p class="warn-text">Aucun document joint — demande créée avant la mise à jour ou via API JSON.</p>`;

  const body = `
    <p><strong>${escapeHtml(app.business_name)}</strong> ${badge(app.status)}</p>
    ${checklistHtml}
    <h4 style="margin:0 0 8px;font-size:0.95rem">Informations entreprise</h4>
    <dl>
      <dt>Catégorie</dt><dd>${escapeHtml(app.category || app.business_type || "—")}</dd>
      <dt>RCCM</dt><dd>${escapeHtml(app.rccm || "—")}</dd>
      <dt>NIF</dt><dd>${escapeHtml(app.tax_id || "—")}</dd>
      <dt>Représentant</dt><dd>${escapeHtml(app.legal_representative || "—")}</dd>
      <dt>Adresse</dt><dd>${escapeHtml(app.business_address || "—")}</dd>
      <dt>Contact pro</dt><dd>${escapeHtml(app.contact_phone || "—")}</dd>
      <dt>Note candidat</dt><dd>${escapeHtml(app.applicant_note || "—")}</dd>
      <dt>Demandé le</dt><dd>${formatDate(app.created_at)}</dd>
      ${app.reviewer_note ? `<dt>Motif refus</dt><dd style="color:#b91c1c">${escapeHtml(app.reviewer_note)}</dd>` : ""}
    </dl>
    <h4 style="margin:16px 0 8px;font-size:0.95rem">Documents justificatifs</h4>
    ${docsHtml}
    <h4 style="margin:0 0 8px;font-size:0.95rem">Demandeur</h4>
    <dl>
      <dt>ID</dt><dd>#${user.id}</dd>
      <dt>Nom</dt><dd>${escapeHtml(user.display_name || "—")}</dd>
      <dt>Téléphone</dt><dd class="pii-masked">${escapeHtml(user.phone_e164 || "—")}</dd>
      <dt>Annonces</dt><dd>${user.listings_count ?? 0}</dd>
      <dt>Signalements</dt><dd>${user.reports_count ?? 0}</dd>
    </dl>
    ${canWrite && app.status === "pending" ? `
      <label for="kyc-internal-note" style="font-size:0.85rem;color:var(--muted)">Note interne équipe (non visible vendeur)</label>
      <textarea id="kyc-internal-note" class="kyc-review-note" placeholder="Contrôles effectués, points à surveiller…">${escapeHtml(data.internal_review_note || "")}</textarea>
      <label for="kyc-reject-note" style="font-size:0.85rem;color:var(--muted)">Motif refus (envoyé au vendeur si refus)</label>
      <textarea id="kyc-reject-note" class="kyc-review-note" placeholder="Ex. RCCM illisible, NIF manquant…"></textarea>
    ` : ""}
  `;

  let actions = `<button type="button" class="btn btn-ghost btn-sm" id="modal-close-btn">Fermer</button>`;
  if (hasPerm(me, PERM.USERS_VIEW)) {
    actions = `<button type="button" class="btn btn-ghost btn-sm" id="kyc-open-user">Fiche utilisateur</button>` + actions;
  }
  if (canWrite && app.status === "pending") {
    actions = `
      <button type="button" class="btn btn-danger btn-sm" id="kyc-reject-btn">Refuser</button>
      <button type="button" class="btn btn-success btn-sm" id="kyc-approve-btn">Approuver</button>
    ` + actions;
  }

  openModal(`Dossier KYC #${applicationId}`, body, actions, { wide: true });

  $("#modal-close-btn")?.addEventListener("click", closeModal);
  $("#kyc-open-user")?.addEventListener("click", () => {
    closeModal();
    showUserDetail(user.id);
  });
  $("#kyc-approve-btn")?.addEventListener("click", async () => {
    if (!confirm("Approuver ce compte professionnel ? Le vendeur recevra une notification.")) return;
    const internal = $("#kyc-internal-note")?.value?.trim() || null;
    await api(`/admin/kyc/${applicationId}/approve`, {
      method: "POST",
      body: JSON.stringify({ internal_note: internal }),
    });
    toast("Compte professionnel approuvé.");
    closeModal();
    navigate("kyc");
  });
  $("#kyc-reject-btn")?.addEventListener("click", async () => {
    const note = $("#kyc-reject-note")?.value?.trim() ?? "";
    if (!note) {
      toast("Indiquez un motif de refus pour le vendeur.", true);
      return;
    }
    if (!confirm("Refuser cette demande ? Le vendeur sera notifié avec le motif.")) return;
    const internal = $("#kyc-internal-note")?.value?.trim() || null;
    await api(`/admin/kyc/${applicationId}/reject`, {
      method: "POST",
      body: JSON.stringify({ note, internal_note: internal }),
    });
    toast("Demande refusée.");
    closeModal();
    navigate("kyc");
  });
}

let reportStatus = "reviewing";

async function renderReports() {
  const el = $("#page-reports");
  el.innerHTML = `
    <div class="panel">
      <p class="page-hint">Étape 3 : annonces masquées automatiquement après 3 signalements. Vérifiez puis bannissez ou rétablissez.</p>
      <div class="toolbar">
        <select id="report-filter">
          <option value="reviewing" ${reportStatus === "reviewing" ? "selected" : ""}>À modérer (auto-masquées)</option>
          <option value="open" ${reportStatus === "open" ? "selected" : ""}>Ouverts</option>
          <option value="closed" ${reportStatus === "closed" ? "selected" : ""}>Clôturés</option>
        </select>
      </div>
      <div class="card-list" id="reports-list"></div>
    </div>
  `;
  $("#report-filter").addEventListener("change", (e) => {
    reportStatus = e.target.value;
    renderReports();
  });
  const { items } = await api(`/admin/reports?status=${reportStatus}`);
  const list = $("#reports-list");
  const me = getMe();
  if (!items.length) {
    list.innerHTML = '<div class="empty">Aucun signalement.</div>';
    return;
  }
  list.innerHTML = items.map((r) => `
    <div class="card-row ${r.auto_hidden ? "card-warn" : ""}">
      <div class="card-meta">
        <h4>${escapeHtml(r.reason)} ${badge(r.status)} ${r.auto_hidden ? '<span class="badge warn">MASQUÉE AUTO</span>' : ""}</h4>
        <div>#${r.id} · ${formatDate(r.created_at)}${r.report_count ? ` · ${r.report_count} signalement(s)` : ""}</div>
        ${r.details ? `<div style="margin-top:6px">${escapeHtml(r.details)}</div>` : ""}
        <div style="margin-top:8px">Par : <span class="pii-masked">${escapeHtml(r.reporter_phone || r.reporter_id)}</span></div>
        ${r.target_user_id ? `<div>Cible : <span class="pii-masked">${escapeHtml(r.target_phone || "")}</span> ${r.target_display_name ? `(${escapeHtml(r.target_display_name)})` : ""}</div>` : ""}
        ${r.listing_id ? `<div>Annonce #${r.listing_id} : ${escapeHtml(r.listing_title || "")} (${escapeHtml(r.listing_status || "")})</div>` : ""}
      </div>
      <div class="card-actions">
        ${r.auto_hidden && r.listing_id && hasPerm(me, PERM.LISTINGS_MODERATE) ? `<button type="button" class="btn btn-primary btn-sm" data-restore-listing="${r.listing_id}">Rétablir annonce</button>` : ""}
        ${r.status !== "closed" && hasPerm(me, PERM.REPORTS_WRITE) ? `<button type="button" class="btn btn-primary btn-sm" data-resolve="${r.id}">Clôturer dossier</button>` : ""}
        ${r.target_user_id && canBan(me) ? `<button type="button" class="btn btn-danger btn-sm" data-ban="${r.target_user_id}">Bannir arnaqueur</button>` : ""}
        ${r.status !== "closed" && canBan(me) ? `<button type="button" class="btn btn-danger btn-sm" data-ban-resolve="${r.id}">Ban + clôturer</button>` : ""}
        ${r.listing_id ? `<button type="button" class="btn btn-ghost btn-sm" data-listing="${r.listing_id}">Voir annonce</button>` : ""}
      </div>
    </div>
  `).join("");
  bindReportActions(list);
}

async function renderEscrow() {
  const el = $("#page-escrow");
  el.innerHTML = `<div class="panel"><div class="card-list" id="escrow-list"></div></div>`;
  const me = getMe();
  const { items } = await api("/admin/escrow/orders");
  const list = $("#escrow-list");
  if (!items.length) {
    list.innerHTML = '<div class="empty">Aucune commande en séquestre.</div>';
    return;
  }
  list.innerHTML = items
    .map(
      (o) => `
    <div class="card-row ${o.deadline_passed ? "card-warn" : ""}">
      <div class="card-meta">
        <h4>Commande #${o.id} ${badge(o.status_label || o.status)}</h4>
        <div>${escapeHtml(o.listing_title || "")} · ${o.amount_cdf} FC</div>
        <div>Code remise : <strong>${escapeHtml(o.handover_code || "—")}</strong></div>
        <div>Acheteur : ${escapeHtml(o.buyer_phone || "")} · Vendeur : ${escapeHtml(o.seller_phone || "")}</div>
        ${o.delivery_deadline_at ? `<div>Échéance : ${formatDate(o.delivery_deadline_at)} ${o.deadline_passed ? '<span class="badge warn">DÉPASSÉ</span>' : ""}</div>` : ""}
        ${o.dispute ? `<div>Litige : ${escapeHtml(o.dispute.reason)}</div>` : ""}
      </div>
      <div class="card-actions">
        ${
          o.status === "sequestre" && hasPerm(me, PERM.ESCROW_RESOLVE)
            ? `<button type="button" class="btn btn-primary btn-sm" data-release="${o.id}">Payer le vendeur</button>
               <button type="button" class="btn btn-danger btn-sm" data-refund="${o.id}">Rembourser acheteur</button>`
            : ""
        }
      </div>
    </div>`
    )
    .join("");
  list.querySelectorAll("[data-release]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      if (!confirm("Libérer les fonds au vendeur (moins commission) ?")) return;
      await api(`/admin/escrow/orders/${btn.dataset.release}/release-seller`, {
        method: "POST",
        body: JSON.stringify({ note: "Résolution admin" }),
      });
      toast("Vendeur payé.");
      renderEscrow();
    });
  });
  list.querySelectorAll("[data-refund]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      if (!confirm("Rembourser l'acheteur via Mobile Money ?")) return;
      await api(`/admin/escrow/orders/${btn.dataset.refund}/refund-buyer`, {
        method: "POST",
        body: JSON.stringify({ note: "Remboursement admin" }),
      });
      toast("Acheteur remboursé.");
      renderEscrow();
    });
  });
}

function bindReportActions(root) {
  root.querySelectorAll("[data-resolve]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      await api(`/admin/reports/${btn.dataset.resolve}/resolve`, { method: "POST" });
      toast("Signalement clôturé.");
      renderReports();
    });
  });
  root.querySelectorAll("[data-review]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      await api(`/admin/reports/${btn.dataset.review}/reviewing`, { method: "POST" });
      toast("Marqué en cours.");
      renderReports();
    });
  });
  root.querySelectorAll("[data-hide-listing]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      if (!confirm("Masquer l'annonce signalée et clôturer le signalement ?")) return;
      await api(`/admin/reports/${btn.dataset.hideListing}/hide-listing`, { method: "POST" });
      toast("Annonce masquée.");
      renderReports();
    });
  });
  root.querySelectorAll("[data-ban]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      if (!confirm("Bannir cet utilisateur ?")) return;
      await api(`/admin/users/${btn.dataset.ban}/ban`, {
        method: "POST",
        body: JSON.stringify({ reason: "Signalement" }),
      });
      toast("Utilisateur banni.");
    });
  });
  root.querySelectorAll("[data-ban-resolve]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      if (!confirm("Bannir l'arnaqueur, masquer l'annonce et clôturer le signalement ?")) return;
      await api(`/admin/reports/${btn.dataset.banResolve}/ban-and-resolve`, { method: "POST" });
      toast("Signalement traité (ban + masquage).");
      renderReports();
    });
  });
  root.querySelectorAll("[data-restore-listing]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      if (!confirm("Rétablir cette annonce dans le catalogue ?")) return;
      await api(`/admin/listings/${btn.dataset.restoreListing}/moderate`, {
        method: "POST",
        body: JSON.stringify({ action: "restore" }),
      });
      toast("Annonce rétablie.");
      renderReports();
    });
  });
  root.querySelectorAll("[data-listing]").forEach((btn) => {
    btn.addEventListener("click", () => showListingDetail(Number(btn.dataset.listing)));
  });
}

async function renderUsers() {
  const el = $("#page-users");
  el.innerHTML = `
    <div class="panel">
      <div class="toolbar">
        <input type="search" id="user-q" placeholder="Téléphone, nom…">
        <select id="user-role">
          <option value="">Tous rôles</option>
          <option value="user">Utilisateur</option>
          <option value="official_seller">Vendeur officiel</option>
        </select>
        <select id="user-banned">
          <option value="">Tous</option>
          <option value="false">Actifs</option>
          <option value="true">Bannis</option>
        </select>
        <button type="button" class="btn btn-primary btn-sm" id="user-search">Rechercher</button>
      </div>
      <div class="panel-body" style="overflow:auto">
        <table class="data-table">
          <thead><tr>
            <th>ID</th><th>Téléphone</th><th>Nom</th><th>Rôle</th><th>Statut</th><th></th>
          </tr></thead>
          <tbody id="users-body"></tbody>
        </table>
      </div>
    </div>
  `;
  const search = async () => {
    const q = $("#user-q").value.trim();
    const role = $("#user-role").value;
    const banned = $("#user-banned").value;
    let url = "/admin/users?limit=100";
    if (q) url += `&q=${encodeURIComponent(q)}`;
    if (role) url += `&role=${encodeURIComponent(role)}`;
    if (banned !== "") url += `&banned=${banned}`;
    const { items, total } = await api(url);
    const tbody = $("#users-body");
    if (!items.length) {
      tbody.innerHTML = '<tr><td colspan="6" class="empty">Aucun utilisateur.</td></tr>';
      return;
    }
    tbody.innerHTML = items.map((u) => `
      <tr>
        <td>${u.id}</td>
        <td class="pii-masked">${escapeHtml(u.phone_e164)}</td>
        <td>${escapeHtml(u.display_name || u.official_name || "—")}</td>
        <td>${u.role === "official_seller" ? badge("official") : escapeHtml(u.role)}</td>
        <td>${u.is_banned ? badge("banned") : badge("ok")}</td>
        <td><button type="button" class="btn btn-ghost btn-sm" data-detail="${u.id}">Détail</button></td>
      </tr>
    `).join("") + `<tr><td colspan="6" style="color:var(--muted);font-size:0.8rem">${total} compte(s)</td></tr>`;
    tbody.querySelectorAll("[data-detail]").forEach((btn) => {
      btn.addEventListener("click", () => showUserDetail(Number(btn.dataset.detail)));
    });
  };
  $("#user-search").addEventListener("click", search);
  $("#user-q").addEventListener("keydown", (e) => { if (e.key === "Enter") search(); });
  await search();
}

async function revealPhone(userId, phoneEl) {
  if (!canRevealPii(getMe())) return;
  if (!confirm("Révéler le numéro ?")) return;
  const res = await api(`/admin/users/${userId}/reveal-pii`, { method: "POST" });
  if (phoneEl) phoneEl.textContent = res.phone_e164;
  toast("Numéro affiché.");
}

async function showUserDetail(userId) {
  const data = await api(`/admin/users/${userId}`);
  const u = data.user;
  const kyc = data.kyc;
  const me = getMe();
  const isStaff = STAFF_ROLES.includes(u.role);
  let actions = `<button type="button" class="btn btn-ghost btn-sm" id="modal-close-btn">Fermer</button>`;
  if (canBan(me) && !u.is_banned && !isStaff) {
    actions = `<button type="button" class="btn btn-danger btn-sm" id="modal-ban">Bannir</button>` + actions;
  }
  if (canBan(me) && u.is_banned) {
    actions = `<button type="button" class="btn btn-success btn-sm" id="modal-unban">Débannir</button>` + actions;
  }
  if (hasPerm(me, PERM.USERS_VIEW) && !isStaff) {
    actions = `<button type="button" class="btn btn-ghost btn-sm" id="modal-warn">Avertissement</button>` + actions;
  }
  if (hasPerm(me, PERM.USERS_REVOKE) && u.role === "official_seller") {
    actions = `<button type="button" class="btn btn-ghost btn-sm" id="modal-revoke">Révoquer statut pro</button>` + actions;
  }
  const revealBtn = data.can_reveal_pii
    ? `<button type="button" class="btn btn-primary btn-sm" id="modal-reveal-pii">Voir le numéro</button>`
    : "";
  openModal(`Utilisateur #${u.id}`, `
    <dl>
      <dt>Téléphone</dt><dd><span id="user-phone-display" class="pii-masked">${escapeHtml(u.phone_e164)}</span></dd>
      <dt>Nom</dt><dd>${escapeHtml(u.display_name || u.official_name || "—")}</dd>
      <dt>Rôle</dt><dd>${escapeHtml(u.role)}</dd>
      <dt>Vendeur vérifié</dt><dd>${u.is_verified_seller ? "Oui" : "Non"}</dd>
      <dt>Statut</dt><dd>${u.is_banned ? "Banni" : "Actif"}</dd>
      <dt>Annonces</dt><dd>${data.listings_count}</dd>
      <dt>Inscrit le</dt><dd>${formatDate(u.created_at)}</dd>
      ${kyc ? `<dt>Dernière KYC</dt><dd>${badge(kyc.status)} ${escapeHtml(kyc.business_name)}</dd>` : ""}
    </dl>
  `, revealBtn + actions);
  $("#modal-close-btn")?.addEventListener("click", closeModal);
  $("#modal-reveal-pii")?.addEventListener("click", () => {
    revealPhone(userId, $("#user-phone-display"));
  });
  $("#modal-warn")?.addEventListener("click", async () => {
    const text = prompt("Message d'avertissement pour l'utilisateur :");
    if (text === null || !text.trim()) return;
    await api(`/admin/users/${userId}/warn`, {
      method: "POST",
      body: JSON.stringify({ message: text.trim() }),
    });
    toast("Avertissement envoyé (message + notification).");
    closeModal();
  });
  $("#modal-ban")?.addEventListener("click", async () => {
    if (!confirm("Bannir cet utilisateur ?")) return;
    await api(`/admin/users/${userId}/ban`, { method: "POST", body: JSON.stringify({}) });
    toast("Utilisateur banni."); closeModal(); renderUsers();
  });
  $("#modal-unban")?.addEventListener("click", async () => {
    await api(`/admin/users/${userId}/unban`, { method: "POST" });
    toast("Utilisateur débanni."); closeModal(); renderUsers();
  });
  $("#modal-revoke")?.addEventListener("click", async () => {
    if (!confirm("Révoquer le statut vendeur officiel ?")) return;
    await api(`/admin/users/${userId}/revoke-official`, { method: "POST" });
    toast("Statut pro révoqué."); closeModal(); renderUsers();
  });
}

async function renderListings() {
  const me = getMe();
  const canMod = hasPerm(me, PERM.LISTINGS_MODERATE);
  const el = $("#page-listings");
  el.innerHTML = `
    <div class="panel">
      <div class="toolbar">
        <input type="search" id="listing-q" placeholder="Titre…">
        <select id="listing-status">
          <option value="">Tous statuts</option>
          <option value="active">Actives</option>
          <option value="hidden">Masquées</option>
          <option value="sold">Vendues</option>
        </select>
        <button type="button" class="btn btn-primary btn-sm" id="listing-search">Filtrer</button>
      </div>
      <div class="panel-body" style="overflow:auto">
        <table class="data-table">
          <thead><tr>
            <th></th><th>ID</th><th>Titre</th><th>Ville</th><th>Prix</th><th>Vendeur</th><th>Statut</th><th></th>
          </tr></thead>
          <tbody id="listings-body"></tbody>
        </table>
      </div>
    </div>
  `;
  const search = async () => {
    const q = $("#listing-q").value.trim();
    const status = $("#listing-status").value;
    let url = "/admin/listings?limit=100";
    if (q) url += `&q=${encodeURIComponent(q)}`;
    if (status) url += `&status=${encodeURIComponent(status)}`;
    const { items } = await api(url);
    const tbody = $("#listings-body");
    if (!items.length) {
      tbody.innerHTML = '<tr><td colspan="8" class="empty">Aucune annonce.</td></tr>';
      return;
    }
    tbody.innerHTML = items.map((l) => `
      <tr>
        <td>${l.image_url ? `<img class="thumb" src="${escapeHtml(l.image_url)}" alt="">` : "—"}</td>
        <td>${l.id}</td>
        <td class="clickable" data-detail="${l.id}">${escapeHtml(l.title)}</td>
        <td>${escapeHtml(l.city)}</td>
        <td>${formatPrice(l.price_cdf)}</td>
        <td><span class="pii-masked">${escapeHtml(l.seller_phone || l.seller_id)}</span>${l.is_official_seller ? " " + badge("official") : ""}</td>
        <td>${badge(l.status)}</td>
        <td>
          ${canMod && l.status === "active" ? `<button type="button" class="btn btn-danger btn-sm" data-hide="${l.id}">Masquer</button>` : ""}
          ${canMod && l.status === "hidden" ? `<button type="button" class="btn btn-success btn-sm" data-restore="${l.id}">Rétablir</button>` : ""}
        </td>
      </tr>
    `).join("");
    tbody.querySelectorAll("[data-detail]").forEach((cell) => {
      cell.addEventListener("click", () => showListingDetail(Number(cell.dataset.detail)));
    });
    if (canMod) {
      tbody.querySelectorAll("[data-hide]").forEach((btn) => {
        btn.addEventListener("click", async () => {
          await api(`/admin/listings/${btn.dataset.hide}/moderate`, { method: "POST", body: JSON.stringify({ action: "hide" }) });
          toast("Annonce masquée."); search();
        });
      });
      tbody.querySelectorAll("[data-restore]").forEach((btn) => {
        btn.addEventListener("click", async () => {
          await api(`/admin/listings/${btn.dataset.restore}/moderate`, { method: "POST", body: JSON.stringify({ action: "restore" }) });
          toast("Annonce rétablie."); search();
        });
      });
    }
  };
  $("#listing-search").addEventListener("click", search);
  $("#listing-q").addEventListener("keydown", (e) => { if (e.key === "Enter") search(); });
  await search();
}

async function showListingDetail(listingId) {
  const me = getMe();
  const canMod = hasPerm(me, PERM.LISTINGS_MODERATE);
  const l = await api(`/admin/listings/${listingId}`);
  const gallery = (l.images || []).map((url) => `<img src="${escapeHtml(url)}" alt="">`).join("");
  const catalogBlock = l.is_catalog && Array.isArray(l.catalog_variants) && l.catalog_variants.length
    ? `
    <div class="catalog-stock-panel">
      <h4>Stock catalogue (vendeur officiel)</h4>
      <div class="catalog-stock-head">
        <span>Taille</span><span>Couleur</span><span>Prix CDF</span><span>Stock</span>
      </div>
      <div id="catalog-stock-rows">
        ${l.catalog_variants.map((v, i) => `
          <div class="catalog-variant-row" data-idx="${i}">
            <input type="text" class="cv-size" value="${escapeHtml(v.size || "")}" placeholder="Taille" ${canMod ? "" : "disabled"}>
            <input type="text" class="cv-color" value="${escapeHtml(v.color || "")}" placeholder="Couleur" ${canMod ? "" : "disabled"}>
            <input type="number" class="cv-price" value="${Number(v.price_cdf || 0)}" min="0" step="1" ${canMod ? "" : "disabled"}>
            <input type="number" class="cv-stock" value="${Number(v.stock || 0)}" min="0" step="1" ${canMod ? "" : "disabled"}>
          </div>
        `).join("")}
      </div>
      ${canMod ? `<button type="button" class="btn btn-primary btn-sm" id="modal-save-catalog" style="margin-top:10px">Enregistrer le stock</button>` : ""}
    </div>
  `
    : "";
  openModal(`Annonce #${l.id}`, `
    <dl>
      <dt>Titre</dt><dd>${escapeHtml(l.title)}</dd>
      <dt>Description</dt><dd>${escapeHtml(l.description || "—")}</dd>
      <dt>Ville</dt><dd>${escapeHtml(l.city)}</dd>
      <dt>Prix</dt><dd>${formatPrice(l.price_cdf)}</dd>
      <dt>Vendeur</dt><dd><span class="pii-masked">${escapeHtml(l.seller_phone || l.seller_id)}</span> ${l.is_official_seller ? badge("officiel") : ""}</dd>
      <dt>Statut</dt><dd>${badge(l.status)}</dd>
      <dt>Publiée</dt><dd>${formatDate(l.created_at)}</dd>
    </dl>
    ${catalogBlock}
    ${gallery ? `<div class="gallery">${gallery}</div>` : ""}
  `, `
    ${canMod && l.status === "active" ? `<button type="button" class="btn btn-danger btn-sm" id="modal-hide">Masquer</button>` : ""}
    ${canMod && l.status === "hidden" ? `<button type="button" class="btn btn-success btn-sm" id="modal-restore">Rétablir</button>` : ""}
    <button type="button" class="btn btn-ghost btn-sm" id="modal-close-btn">Fermer</button>
  `);
  $("#modal-close-btn")?.addEventListener("click", closeModal);
  $("#modal-save-catalog")?.addEventListener("click", async () => {
    const rows = [...document.querySelectorAll(".catalog-variant-row")];
    const variants = rows.map((row) => ({
      size: row.querySelector(".cv-size")?.value?.trim(),
      color: row.querySelector(".cv-color")?.value?.trim() || null,
      price_cdf: Number(row.querySelector(".cv-price")?.value || 0),
      stock: Number(row.querySelector(".cv-stock")?.value || 0),
    })).filter((v) => v.size);
    if (!variants.length) {
      toast("Au moins une variante avec taille est requise.", true);
      return;
    }
    try {
      await api(`/admin/listings/${listingId}/catalog-stock`, {
        method: "PATCH",
        body: JSON.stringify({ variants }),
      });
      toast("Stock catalogue mis à jour.");
      closeModal();
      renderListings();
    } catch (ex) {
      toast(ex.message, true);
    }
  });
  $("#modal-hide")?.addEventListener("click", async () => {
    await api(`/admin/listings/${listingId}/moderate`, { method: "POST", body: JSON.stringify({ action: "hide" }) });
    toast("Annonce masquée."); closeModal(); renderListings();
  });
  $("#modal-restore")?.addEventListener("click", async () => {
    await api(`/admin/listings/${listingId}/moderate`, { method: "POST", body: JSON.stringify({ action: "restore" }) });
    toast("Annonce rétablie."); closeModal(); renderListings();
  });
}

async function renderAudit() {
  const el = $("#page-audit");
  el.innerHTML = `
    <div class="panel">
      <div class="panel-body" style="overflow:auto">
        <table class="data-table audit-table">
          <thead><tr>
            <th>Date</th><th>Agent</th><th>Action</th><th>Ressource</th><th>Détail</th>
          </tr></thead>
          <tbody id="audit-body"><tr><td colspan="5" class="empty">Chargement…</td></tr></tbody>
        </table>
      </div>
    </div>
  `;
  const { items } = await api("/admin/audit?limit=100");
  const tbody = $("#audit-body");
  if (!items.length) {
    tbody.innerHTML = '<tr><td colspan="5" class="empty">Aucune entrée.</td></tr>';
    return;
  }
  tbody.innerHTML = items.map((e) => `
    <tr>
      <td>${formatDate(e.created_at)}</td>
      <td class="pii-masked">${escapeHtml(e.actor_phone || e.actor_id || "—")}</td>
      <td>${escapeHtml(auditActionLabel(e.action))}</td>
      <td>${escapeHtml(e.resource_type || "")} #${e.resource_id ?? "—"}</td>
      <td><code class="audit-detail">${escapeHtml(JSON.stringify(e.detail || {}))}</code></td>
    </tr>
  `).join("");
}

let supportSelectedUserId = null;

async function renderSupport() {
  const me = getMe();
  const canReply = hasPerm(me, PERM.SUPPORT_REPLY);
  const el = $("#page-support");
  el.innerHTML = `
    <p class="panel-hint support-intro">
      Les utilisateurs écrivent au <strong>Centre d'aide SombaTeka</strong> depuis l'app.
      Vos réponses partent sous ce nom unique (jamais votre compte personnel) avec notification in-app.
    </p>
    <div class="support-desk">
      <div class="panel support-list-panel">
        <div class="panel-head">Conversations</div>
        <div id="support-conv-list" class="support-conv-list"><div class="empty">Chargement…</div></div>
      </div>
      <div class="panel support-thread-panel">
        <div class="panel-head" id="support-thread-title">Sélectionnez une conversation</div>
        <div id="support-thread-body" class="support-thread-body">
          <div class="empty">Choisissez un utilisateur à gauche pour lire et répondre.</div>
        </div>
        ${canReply ? `
          <form id="support-reply-form" class="support-reply-form" hidden>
            <textarea id="support-reply-input" rows="3" maxlength="4000" placeholder="Votre réponse (signée Équipe SombaTeka)…" required></textarea>
            <div class="support-reply-actions">
              <label class="support-sig-opt"><input type="checkbox" id="support-add-signature" checked> Signature équipe</label>
              <button type="submit" class="btn btn-primary">Envoyer</button>
            </div>
          </form>
        ` : ""}
      </div>
    </div>
  `;

  const { items } = await api("/admin/support/conversations");
  const list = $("#support-conv-list");
  if (!items.length) {
    list.innerHTML = '<div class="empty">Aucune demande pour le moment.</div>';
    return;
  }

  list.innerHTML = items.map((c) => `
    <button type="button" class="support-conv-item ${supportSelectedUserId === c.user_id ? "active" : ""}" data-user="${c.user_id}">
      <div class="support-conv-top">
        <strong>${escapeHtml(c.display_name)}</strong>
        ${c.unread_count ? `<span class="nav-badge warn">${c.unread_count}</span>` : ""}
      </div>
      <div class="support-conv-preview">${escapeHtml(c.last_message || "—")}</div>
      <div class="support-conv-meta">${formatDate(c.last_at)} · ${escapeHtml(c.role)}</div>
    </button>
  `).join("");

  list.querySelectorAll(".support-conv-item").forEach((btn) => {
    btn.addEventListener("click", () => openSupportThread(Number(btn.dataset.user)));
  });

  if (supportSelectedUserId && items.some((c) => c.user_id === supportSelectedUserId)) {
    await openSupportThread(supportSelectedUserId);
  } else if (items.some((c) => c.unread_count > 0)) {
    const first = items.find((c) => c.unread_count > 0) || items[0];
    await openSupportThread(first.user_id);
  }
}

async function openSupportThread(userId) {
  supportSelectedUserId = userId;
  $$(".support-conv-item").forEach((b) => b.classList.toggle("active", Number(b.dataset.user) === userId));

  const title = $("#support-thread-title");
  const body = $("#support-thread-body");
  const form = $("#support-reply-form");
  body.innerHTML = '<div class="empty">Chargement…</div>';

  const data = await api(`/admin/support/conversations/${userId}`);
  title.innerHTML = `
    <span>${escapeHtml(data.user.display_name)}</span>
    <small class="pii-masked">${escapeHtml(data.user.phone_e164)}</small>
  `;

  if (!data.items.length) {
    body.innerHTML = '<div class="empty">Aucun message dans ce fil.</div>';
  } else {
    body.innerHTML = data.items.map((m) => `
      <div class="support-bubble ${m.from_team ? "from-team" : "from-user"}">
        <div class="support-bubble-meta">${m.from_team ? "Équipe SombaTeka" : "Utilisateur"} · ${formatDate(m.created_at)}</div>
        <div class="support-bubble-text">${escapeHtml(m.content).replace(/\n/g, "<br>")}</div>
      </div>
    `).join("");
    body.scrollTop = body.scrollHeight;
  }

  if (form) {
    form.hidden = false;
    form.onsubmit = async (e) => {
      e.preventDefault();
      const input = $("#support-reply-input");
      const content = input.value.trim();
      if (!content) return;
      const addSig = $("#support-add-signature")?.checked !== false;
      try {
        await api(`/admin/support/conversations/${userId}/reply`, {
          method: "POST",
          body: JSON.stringify({ content, add_signature: addSig }),
        });
        input.value = "";
        toast("Réponse envoyée — l'utilisateur est notifié.");
        await refreshStats();
        await renderSupport();
      } catch (ex) {
        toast(ex.message, true);
      }
    };
  }

  await refreshStats();
}

async function renderTeam() {
  const me = getMe();
  const manage = canManageTeam(me);
  const isSuper = me.role === "super_admin";
  const el = $("#page-team");
  el.innerHTML = `
    ${manage ? `
      <div class="panel team-invite-panel">
        <div class="panel-head">➕ Ajouter un membre</div>
        <form id="team-invite-form" class="team-invite-form">
          <label>Téléphone <input name="phone" type="tel" required placeholder="+243900000000"></label>
          <label>Nom affiché <input name="display_name" type="text" maxlength="80" placeholder="Optionnel"></label>
          <label>Rôle
            <select name="role" required>
              <option value="moderator">Modérateur</option>
              <option value="admin">Administrateur</option>
              ${isSuper ? '<option value="super_admin">Super administrateur</option>' : ""}
            </select>
          </label>
          <label>Mot de passe <input name="password" type="password" required minlength="8" autocomplete="new-password"></label>
          <button type="submit" class="btn btn-primary">Créer / inviter</button>
        </form>
        <p class="panel-hint">Chaque membre se connecte avec son téléphone et son mot de passe personnel sur /admin/login.</p>
      </div>
    ` : `
      <p class="panel-hint team-readonly-hint">Seul le super administrateur peut ajouter ou modifier les membres. Votre rôle : <strong>${escapeHtml(me.role_label || me.role)}</strong>.</p>
    `}
    <div class="panel">
      <div class="panel-head">Membres de l'équipe</div>
      <div class="card-list" id="team-list"></div>
    </div>
    <div class="panel">
      <div class="panel-head">Historique d'activité</div>
      <div class="toolbar team-activity-toolbar">
        <label>Filtrer par membre
          <select id="team-activity-filter">
            <option value="">Toute l'équipe</option>
          </select>
        </label>
        <button type="button" class="btn btn-ghost btn-sm" id="team-activity-refresh">Actualiser</button>
      </div>
      <div class="table-wrap">
        <table class="data-table team-activity-table">
          <thead>
            <tr><th>Date</th><th>Membre</th><th>Action</th><th>Ressource</th><th>Détail</th></tr>
          </thead>
          <tbody id="team-activity-body"><tr><td colspan="5" class="empty">Chargement…</td></tr></tbody>
        </table>
      </div>
    </div>
  `;

  if (manage) {
    $("#team-invite-form").addEventListener("submit", async (e) => {
      e.preventDefault();
      const fd = new FormData(e.target);
      try {
        const res = await api("/admin/team/invite", {
          method: "POST",
          body: JSON.stringify({
            phone_e164: fd.get("phone"),
            display_name: fd.get("display_name") || null,
            role: fd.get("role"),
            password: fd.get("password"),
          }),
        });
        toast(res.created ? "Membre créé." : "Accès mis à jour.");
        e.target.reset();
        renderTeam();
      } catch (ex) {
        toast(ex.message, true);
      }
    });
  }

  const { items } = await api("/admin/team");
  const list = $("#team-list");
  const filter = $("#team-activity-filter");

  if (!items.length) {
    list.innerHTML = '<div class="empty">Aucun membre staff.</div>';
  } else {
    items.forEach((m) => {
      const opt = document.createElement("option");
      opt.value = String(m.id);
      opt.textContent = `${m.display_name || m.phone_e164} (${m.role_label || m.role})`;
      filter.appendChild(opt);
    });

    list.innerHTML = items.map((m) => `
      <div class="card-row">
        <div class="card-meta">
          <h4>${escapeHtml(m.display_name || "Sans nom")} ${m.is_self ? badge("vous") : ""}</h4>
          <div class="pii-masked">${escapeHtml(m.phone_e164)}</div>
          <div>${escapeHtml(m.role_label || m.role)} ${m.is_banned ? badge("banned") : ""} ${m.has_admin_password ? badge("mdp ok") : badge("sans mdp")}</div>
          <div class="team-activity-summary">${m.activity_count || 0} action(s) · dernière : ${formatDate(m.last_activity_at)}</div>
        </div>
        <div class="card-actions">
          <button type="button" class="btn btn-ghost btn-sm" data-history="${m.id}">Historique</button>
          ${manage && !m.is_self ? `
            <select class="role-select" data-member="${m.id}" data-current="${m.role}">
              <option value="moderator" ${m.role === "moderator" ? "selected" : ""}>Modérateur</option>
              <option value="admin" ${m.role === "admin" ? "selected" : ""}>Administrateur</option>
              ${isSuper ? `<option value="super_admin" ${m.role === "super_admin" ? "selected" : ""}>Super administrateur</option>` : ""}
            </select>
            <button type="button" class="btn btn-ghost btn-sm" data-password="${m.id}">Mot de passe</button>
            <button type="button" class="btn btn-danger btn-sm" data-revoke="${m.id}">Révoquer</button>
          ` : ""}
        </div>
      </div>
    `).join("");
  }

  async function loadTeamActivity(actorId = "") {
    const tbody = $("#team-activity-body");
    tbody.innerHTML = '<tr><td colspan="5" class="empty">Chargement…</td></tr>';
    try {
      const qs = actorId ? `?actor_id=${encodeURIComponent(actorId)}&limit=80` : "?limit=80";
      const { items: logs } = await api(`/admin/team/activity${qs}`);
      if (!logs.length) {
        tbody.innerHTML = '<tr><td colspan="5" class="empty">Aucune activité enregistrée.</td></tr>';
        return;
      }
      tbody.innerHTML = logs.map((e) => `
        <tr>
          <td>${formatDate(e.created_at)}</td>
          <td>${escapeHtml(e.actor_name || e.actor_phone || `#${e.actor_id}`)}</td>
          <td>${escapeHtml(auditActionLabel(e.action))}</td>
          <td>${escapeHtml(e.resource_type || "")} #${e.resource_id ?? "—"}</td>
          <td><code class="audit-detail">${escapeHtml(JSON.stringify(e.detail || {}))}</code></td>
        </tr>
      `).join("");
    } catch (ex) {
      tbody.innerHTML = `<tr><td colspan="5" class="empty">${escapeHtml(ex.message)}</td></tr>`;
    }
  }

  filter.addEventListener("change", () => loadTeamActivity(filter.value));
  $("#team-activity-refresh").addEventListener("click", () => loadTeamActivity(filter.value));
  await loadTeamActivity();

  list.querySelectorAll("[data-history]").forEach((btn) => {
    btn.addEventListener("click", () => {
      filter.value = btn.dataset.history;
      loadTeamActivity(filter.value);
      $("#team-activity-body")?.scrollIntoView({ behavior: "smooth", block: "nearest" });
    });
  });

  if (manage) {
    list.querySelectorAll(".role-select").forEach((sel) => {
      sel.addEventListener("change", async () => {
        const id = sel.dataset.member;
        const role = sel.value;
        if (role === sel.dataset.current) return;
        if (!confirm("Changer le rôle ?")) {
          sel.value = sel.dataset.current;
          return;
        }
        try {
          await api(`/admin/team/${id}`, { method: "PATCH", body: JSON.stringify({ role }) });
          toast("Rôle mis à jour.");
          renderTeam();
        } catch (ex) {
          toast(ex.message, true);
          sel.value = sel.dataset.current;
        }
      });
    });
    list.querySelectorAll("[data-password]").forEach((btn) => {
      btn.addEventListener("click", () => {
        const id = btn.dataset.password;
        openModal(
          "Nouveau mot de passe",
          `<label style="display:block;margin-bottom:8px">Mot de passe (min. 8 caractères)
            <input id="team-new-password" type="password" minlength="8" autocomplete="new-password" style="width:100%;margin-top:6px;padding:9px 11px;border:1px solid var(--border);border-radius:8px">
          </label>`,
          `<button type="button" class="btn btn-primary" id="team-save-password">Enregistrer</button>`,
        );
        $("#team-save-password").addEventListener("click", async () => {
          const password = $("#team-new-password").value;
          if (password.length < 8) {
            toast("Mot de passe trop court (8 caractères min.).", true);
            return;
          }
          try {
            await api(`/admin/team/${id}/password`, { method: "POST", body: JSON.stringify({ password }) });
            toast("Mot de passe mis à jour.");
            closeModal();
            renderTeam();
          } catch (ex) {
            toast(ex.message, true);
          }
        });
      });
    });
    list.querySelectorAll("[data-revoke]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        if (!confirm("Révoquer l'accès ?")) return;
        await api(`/admin/team/${btn.dataset.revoke}/revoke-access`, { method: "POST" });
        toast("Accès révoqué.");
        renderTeam();
      });
    });
  }
}

const TRASH_TYPE_LABELS = {
  listing: "Annonce",
  publication: "Publication",
  conversation: "Conversation",
};

async function renderTrash() {
  const el = $("#page-trash");
  if (!canManageTrash(getMe())) {
    el.innerHTML = `<p class="muted">Réservé au super administrateur.</p>`;
    return;
  }
  el.innerHTML = `
    <div class="panel">
      <div class="panel-head">
        <h3>Corbeille SombaTeka</h3>
        <p class="muted">Annonces, publications et conversations supprimées — restauration ou purge définitive.</p>
      </div>
      <div class="panel-actions" style="margin-bottom:1rem;display:flex;gap:8px;flex-wrap:wrap">
        <button type="button" class="btn btn-ghost btn-sm" id="trash-filter-all">Tout</button>
        <button type="button" class="btn btn-ghost btn-sm" id="trash-filter-publication">Publications</button>
        <button type="button" class="btn btn-ghost btn-sm" id="trash-filter-listing">Annonces</button>
        <button type="button" class="btn btn-danger btn-sm" id="trash-reset-beta" style="margin-left:auto">Réinitialiser données beta</button>
      </div>
      <div class="table-wrap">
        <table class="data-table">
          <thead><tr><th>Type</th><th>Titre</th><th>Clé</th><th>Supprimé le</th><th></th></tr></thead>
          <tbody id="trash-body"></tbody>
        </table>
      </div>
    </div>`;

  let filter = "";
  async function loadTrash() {
    let url = "/admin/trash?limit=100";
    if (filter) url += `&entity_type=${filter}`;
    const data = await api(url);
    const tbody = $("#trash-body");
    tbody.innerHTML = "";
    for (const item of data.items || []) {
      const tr = document.createElement("tr");
      const deleted = item.deleted_at ? new Date(item.deleted_at).toLocaleString("fr-FR") : "—";
      tr.innerHTML = `
        <td>${TRASH_TYPE_LABELS[item.entity_type] || item.entity_type}</td>
        <td>${escapeHtml(item.title || "—")}</td>
        <td><code>${escapeHtml(item.entity_key || "")}</code></td>
        <td>${deleted}</td>
        <td class="actions">
          <button type="button" class="btn btn-sm btn-primary" data-restore-trash="${item.id}">Restaurer</button>
          <button type="button" class="btn btn-sm btn-danger" data-purge-trash="${item.id}">Purger</button>
        </td>`;
      tbody.appendChild(tr);
    }
    tbody.querySelectorAll("[data-restore-trash]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        await api(`/admin/trash/${btn.dataset.restoreTrash}/restore`, { method: "POST" });
        toast("Élément restauré.");
        loadTrash();
      });
    });
    tbody.querySelectorAll("[data-purge-trash]").forEach((btn) => {
      btn.addEventListener("click", async () => {
        if (!confirm("Suppression définitive — irréversible. Continuer ?")) return;
        await api(`/admin/trash/${btn.dataset.purgeTrash}/purge`, { method: "POST" });
        toast("Élément purgé.");
        loadTrash();
      });
    });
  }

  $("#trash-filter-all").addEventListener("click", () => { filter = ""; loadTrash(); });
  $("#trash-filter-publication").addEventListener("click", () => { filter = "publication"; loadTrash(); });
  $("#trash-filter-listing").addEventListener("click", () => { filter = "listing"; loadTrash(); });
  $("#trash-reset-beta").addEventListener("click", async () => {
    if (!confirm("SUPPRIMER tous les utilisateurs et toutes les annonces sauf les super administrateurs ?")) return;
    if (!confirm("Dernière confirmation — cette action est irréversible.")) return;
    const r = await api("/admin/trash/reset-beta-data", { method: "POST" });
    toast("Données beta réinitialisées.");
    console.log(r.summary);
    loadTrash();
  });

  await loadTrash();
}

$("#logout-btn").addEventListener("click", logout);
$("#refresh-btn").addEventListener("click", () => loadPage(currentPage));
$("#modal-close").addEventListener("click", closeModal);
$$(".nav-item").forEach((btn) => btn.addEventListener("click", () => navigate(btn.dataset.page)));

async function initDashboard() {
  if (!isAuthenticated()) {
    window.location.replace("/admin/login");
    return;
  }
  try {
    const meRes = await api("/admin/me");
    updateMe({ ...meRes.user, permissions: meRes.permissions });
    if (!isStaffRole(meRes.user.role)) {
      clearSession();
      window.location.replace("/admin/login");
      return;
    }
    applyNavPermissions();
    updateIdentity();
    navigate(firstAllowedPage());
  } catch {
    clearSession();
    window.location.replace("/admin/login");
  }
}

initDashboard();
