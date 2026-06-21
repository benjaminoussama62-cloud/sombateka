## Backend (SombaTeka API)

### Lancer (Windows, SQLite)
```bash
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

### Panneau admin (web, hors app mobile)

- URL : `http://localhost:8000/admin/`
- Compte dev : `+243900000001` / mot de passe `developer` (`POST /api/auth/dev/login`)
- API modération : `/api/admin/*` (rôle `admin` ou `moderator`)

### Endpoints (v0)
- `GET /healthz`
- `POST /api/auth/otp/send` (dev retourne `dev_code`)
- `POST /api/auth/otp/verify` → JWT
- `POST /api/auth/dev/login` (**dev only**, bypass SMS) → JWT
- `GET /api/auth/me`
- `POST /api/listings/` (**requires** `Authorization` + `X-Idempotency-Key`)
- `GET /api/listings`
- `GET /api/listings/{id}`
- `POST /api/listings/{id}/images` (**requires** `Authorization` + `X-Idempotency-Key`)
- `GET /uploads/<key>` (dev static)

### Notes sécurité (v0)
- Rate limit dev (IP sliding window). En prod: WAF/CDN + Redis.
- Idempotency: protège les écritures contre double-submit (click réseau lent).

