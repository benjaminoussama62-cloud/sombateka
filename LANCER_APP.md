# Lancer SombaTeka (éviter l'erreur Chrome iframe)

## Pourquoi l'erreur ?

`Unsafe attempt to load URL http://localhost:8081/ from frame with URL chrome-error://chromewebdata/`

Cela arrive si tu ouvres l'app dans le **navigateur intégré Cursor** (iframe). Chrome **interdit** localhost dans une iframe pour des raisons de sécurité.

**Solution : ouvrir dans Google Chrome normal**, pas dans l'aperçu Cursor.

---

## 1) Backend (terminal 1)

```powershell
cd "c:\Users\ADMIN\DevAlpha org\SombaTeka\backend"
.\.venv\Scripts\uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Vérifier : http://127.0.0.1:8000/healthz → `{"ok":true}`

---

## 2) Mobile Web (terminal 2) — mode recommandé

```powershell
cd "c:\Users\ADMIN\DevAlpha org\SombaTeka\mobile"
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8081 --no-web-resources-cdn --release
```

**iPhone (Safari)** : même Wi‑Fi → `http://VOTRE_IP_PC:8081` (ex. `http://192.168.1.5:8081`).

- `--no-web-resources-cdn` : CanvasKit servi par le PC (évite écran blanc).
- `--release` : évite l’erreur debug `loader.parentNode.removeChild` sur Safari.

Puis **dans Chrome** (application séparée), tape à la main :

**http://127.0.0.1:8081**

(Ne pas utiliser le panneau "Simple Browser" de Cursor.)

---

## Alternative : Chrome direct

```powershell
flutter run -d chrome --web-port 8081 --dart-define=ST_API_BASE_URL=http://127.0.0.1:8000 --dart-define=SENTRY_DSN=
```

Chrome s'ouvrira tout seul.

---

## Pare-feu

Autoriser TCP **8000** et **8081** si tu testes depuis un téléphone sur le même Wi‑Fi.
