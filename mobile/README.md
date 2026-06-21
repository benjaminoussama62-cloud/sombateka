## Mobile (Flutter)

### Lancer (sans Android Studio)
Le plus simple pour voir l’évolution sur ton PC: **Flutter Web (Chrome)**.

1) Démarre le backend (dans `backend/`):

```bash
uvicorn app.main:app --host 0.0.0.0 --reload --port 8000
```

2) Démarre l’app (dans `mobile/`):

```bash
flutter pub get
flutter run -d chrome
```

### iPhone (aperçu rapide, sans Android Studio)
```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

Puis sur iPhone (même réseau): `http://<IP_PC>:8080`

Si Safari ne charge pas: ouvre le pare-feu Windows pour **TCP 8080** + **TCP 8000**.

### URL API (dev)
- **Web**: par défaut on force `http://<même-host>:8000/api` via `web/index.html` (`window.stApiBaseUrl`).
  - override compile-time: `--dart-define=ST_API_BASE_URL=http://172.20.10.3:8000`
- **Desktop / iOS simulator**: `http://127.0.0.1:8000/api`
- **Android emulator** (plus tard, quand SDK installé): `http://10.0.2.2:8000/api`

### Écrans (v0)
- Auth OTP (dev)
- Feed annonces
