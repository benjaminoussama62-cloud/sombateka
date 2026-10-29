from pathlib import Path

p = Path("backend/app/routers/seo.py")
text = p.read_text(encoding="utf-8")
start = text.index("def _css() -> str:")
end = text.index("def _active_listing_stmt():")

new = '''def _css() -> str:
    return f"""
@import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;600;700;800&display=swap');
:root {{ --navy:{_NAVY}; --gold:{_GOLD}; --ink:#0f172a; --muted:#64748b; --line:#e2e8f0; --bg:#f5f7fc; --deep:#060d24; }}
* {{ box-sizing:border-box; }}
body {{ margin:0; font-family:"Plus Jakarta Sans",system-ui,sans-serif; color:var(--ink); background:var(--bg); line-height:1.55; }}
a {{ color:var(--navy); }}
.top {{ background:linear-gradient(180deg,#060d24,#0D1B4B); color:#fff; border-bottom:1px solid rgba(251,191,36,.2); }}
.top-inner {{ max-width:1100px; margin:0 auto; padding:14px 20px; display:flex; align-items:center; justify-content:space-between; gap:16px; }}
.brand {{ display:inline-flex; align-items:center; gap:10px; font-weight:800; font-size:1.2rem; letter-spacing:-.02em; color:var(--gold); text-decoration:none; }}
.brand img {{ width:36px; height:36px; display:block; }}
.nav a {{ color:rgba(255,255,255,.85); text-decoration:none; margin-left:16px; font-size:.9rem; font-weight:600; }}
.wrap {{ max-width:1100px; margin:0 auto; padding:24px 20px 48px; }}
.crumbs {{ font-size:.85rem; color:var(--muted); margin-bottom:18px; }}
.crumbs a {{ color:var(--muted); text-decoration:none; }}
.grid {{ display:grid; grid-template-columns:1.2fr .8fr; gap:28px; }}
@media (max-width:840px) {{ .grid {{ grid-template-columns:1fr; }} .apps-soon-inner,.footer-inner {{ grid-template-columns:1fr !important; }} }}
.gallery img {{ width:100%; border-radius:12px; display:block; background:#fff; border:1px solid var(--line); }}
.thumbs {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(72px,1fr)); gap:8px; margin-top:10px; }}
.thumbs img {{ aspect-ratio:1; object-fit:cover; border-radius:8px; border:1px solid var(--line); }}
h1 {{ font-size:clamp(1.6rem,3.5vw,2.35rem); line-height:1.12; margin:0 0 12px; font-weight:800; letter-spacing:-.03em; color:var(--navy); }}
.price {{ font-size:1.65rem; font-weight:800; color:var(--navy); margin:0 0 10px; }}
.meta {{ font-size:.92rem; color:var(--muted); margin:0 0 8px; }}
.badge {{ display:inline-block; font-size:.75rem; font-weight:700; letter-spacing:.04em; text-transform:uppercase; background:#ecfdf5; color:#047857; padding:4px 10px; border-radius:999px; margin-right:8px; }}
.badge.warn {{ background:#fff7ed; color:#c2410c; }}
.panel {{ background:#fff; border:1px solid var(--line); padding:22px; border-radius:14px; }}
.btn {{ display:inline-block; font-weight:800; background:var(--navy); color:#fff !important; text-decoration:none; padding:14px 22px; border-radius:12px; }}
.btn.alt {{ background:#fff; color:var(--navy) !important; border:2px solid var(--navy); }}
.desc {{ white-space:pre-wrap; font-size:1.02rem; }}
.section-title {{ font-size:1.05rem; font-weight:800; margin:40px 0 16px; letter-spacing:.04em; text-transform:uppercase; color:var(--navy); }}
.cards {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(200px,1fr)); gap:16px; }}
.card {{ background:#fff; border:1px solid var(--line); border-radius:14px; overflow:hidden; text-decoration:none; color:inherit; display:block; }}
.card:hover {{ border-color:var(--navy); }}
.card img {{ width:100%; aspect-ratio:1; object-fit:cover; background:#e2e8f0; display:block; }}
.card .body {{ padding:12px; }}
.card .t {{ font-weight:700; font-size:.92rem; margin:0 0 6px; display:-webkit-box; -webkit-line-clamp:2; -webkit-box-orient:vertical; overflow:hidden; }}
.card .p {{ font-weight:800; color:var(--navy); margin:0; font-size:.95rem; }}
.apps-soon {{ background:linear-gradient(145deg,var(--deep),var(--navy)); color:#fff; padding:28px 20px; border-block:1px solid rgba(251,191,36,.25); }}
.apps-soon-inner {{ max-width:1100px; margin:0 auto; display:grid; grid-template-columns:1.2fr .8fr; gap:20px; align-items:center; }}
.apps-soon h2 {{ margin:0 0 8px; font-size:1.35rem; letter-spacing:-.02em; }}
.apps-soon p {{ margin:0; color:rgba(255,255,255,.78); }}
.apps-platforms {{ display:grid; grid-template-columns:1fr 1fr; gap:10px; }}
.apps-platform {{ display:flex; gap:10px; align-items:center; padding:12px; border-radius:12px; background:rgba(255,255,255,.07); border:1px solid rgba(255,255,255,.12); }}
.apps-platform img {{ width:28px; height:28px; }}
.apps-platform strong {{ display:block; font-size:.9rem; }}
.apps-platform span {{ font-size:.72rem; font-weight:700; letter-spacing:.05em; text-transform:uppercase; color:var(--gold); }}
.footer {{ background:linear-gradient(180deg,#0a1438,var(--deep)); color:rgba(255,255,255,.75); margin-top:0; padding:40px 20px 24px; border-top:1px solid rgba(251,191,36,.22); }}
.footer-inner {{ max-width:1100px; margin:0 auto; display:grid; grid-template-columns:1.4fr 1fr 1fr; gap:24px; }}
.footer-brand {{ display:flex; gap:12px; align-items:flex-start; }}
.footer-brand img {{ width:48px; height:48px; }}
.footer-brand strong {{ display:block; color:var(--gold); font-size:1.2rem; margin-bottom:4px; }}
.footer a {{ color:rgba(255,255,255,.85); text-decoration:none; font-weight:600; }}
.footer-col h3 {{ margin:0 0 10px; font-size:.72rem; letter-spacing:.12em; text-transform:uppercase; color:var(--gold); }}
.footer-col a {{ display:block; margin-bottom:8px; }}
.footer-bottom {{ max-width:1100px; margin:28px auto 0; padding-top:18px; border-top:1px solid rgba(255,255,255,.1); font-size:.85rem; color:rgba(255,255,255,.55); text-align:center; }}
.pager {{ display:flex; gap:12px; margin-top:28px; }}
.hero-cat {{ padding:28px 0 8px; }}
.hero-cat p {{ color:var(--muted); max-width:52ch; }}
"""


def _shell(title: str, description: str, canonical: str, body: str, json_lds: list[dict], extra_head: str = "") -> str:
    scripts = "\\n".join(
        f'<script type="application/ld+json">{json.dumps(j, ensure_ascii=False)}</script>' for j in json_lds
    )
    base = html.escape(_base_url())
    return f"""<!DOCTYPE html>
<html lang="fr-CD">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{html.escape(title)}</title>
  <meta name="description" content="{html.escape(description)}" />
  <meta name="robots" content="index, follow, max-image-preview:large, max-snippet:-1" />
  <meta name="theme-color" content="{_NAVY}" />
  <link rel="canonical" href="{html.escape(canonical)}" />
  <link rel="alternate" hreflang="fr-CD" href="{html.escape(canonical)}" />
  <link rel="alternate" hreflang="x-default" href="{html.escape(canonical)}" />
  {extra_head}
  {scripts}
  <style>{_css()}</style>
</head>
<body>
  <header class="top">
    <div class="top-inner">
      <a class="brand" href="{base}/">
        <img src="{base}/assets/logo-mark.svg" width="36" height="36" alt="Logo SombaTeka" />
        {_BRAND}
      </a>
      <nav class="nav" aria-label="Navigation">
        <a href="{base}/catalogue">Catalogue</a>
        <a href="{base}/about">À propos</a>
        <a href="{base}/">App web</a>
      </nav>
    </div>
  </header>
  <section class="apps-soon" aria-label="Applications mobiles">
    <div class="apps-soon-inner">
      <div>
        <h2>Android et iOS ne sont pas encore disponibles</h2>
        <p>Utilisez SombaTeka sur le <strong>web</strong> dès maintenant. Les apps natives arriveront bientôt sur Google Play et l’App Store.</p>
      </div>
      <div class="apps-platforms">
        <div class="apps-platform">
          <img src="{base}/assets/android-logo.svg" width="28" height="28" alt="Android" />
          <div><strong>Android</strong><span>Bientôt</span></div>
        </div>
        <div class="apps-platform">
          <img src="{base}/assets/apple-logo.svg" width="28" height="28" alt="Apple" />
          <div><strong>iPhone</strong><span>Bientôt</span></div>
        </div>
      </div>
    </div>
  </section>
  {body}
  <footer class="footer">
    <div class="footer-inner">
      <div class="footer-brand">
        <img src="{base}/assets/logo-mark.svg" width="48" height="48" alt="Logo SombaTeka" />
        <div>
          <strong>{_BRAND}</strong>
          <p style="margin:0;max-width:28ch">Marketplace premium RDC — web maintenant, apps bientôt.</p>
        </div>
      </div>
      <div class="footer-col">
        <h3>Explorer</h3>
        <a href="{base}/">App web</a>
        <a href="{base}/catalogue">Catalogue</a>
        <a href="{base}/about">À propos</a>
      </div>
      <div class="footer-col">
        <h3>Légal</h3>
        <a href="{base}/terms">CGU</a>
        <a href="{base}/privacy">Confidentialité</a>
        <a href="{base}/account-deletion">Suppression de compte</a>
      </div>
    </div>
    <div class="footer-bottom">&copy; {datetime.now(timezone.utc).year} {_BRAND} — République Démocratique du Congo</div>
  </footer>
</body>
</html>"""


'''

# Fix accidental double-escape of \\n in scripts join - should be real \n in source
new = new.replace('"\\\\n".join', '"\\n".join')

p.write_text(text[:start] + new + text[end:], encoding="utf-8")
print("ok")
