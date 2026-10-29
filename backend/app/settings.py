from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "SombaTeka API"
    environment: str = "dev"
    api_prefix: str = "/api"
    public_base_url: str = "http://localhost:8000"

    database_url: str = "sqlite:///./sombateka.v2.sqlite"
    db_pool_size: int = 20
    db_max_overflow: int = 40

    redis_url: str = "redis://localhost:6379/0"
    celery_broker_url: str | None = None
    celery_result_backend: str | None = None

    jwt_secret: str = "dev-only-change-me"
    jwt_issuer: str = "sombateka"
    jwt_audience: str = "sombateka-mobile"
    access_token_minutes: int = 60 * 24 * 7

    rate_limit_per_minute: int = 120
    use_redis_rate_limit: bool = True
    redis_password: str = ""

    cors_origins: str = ""
    cors_origin_regex: str = ""

    allow_dev_password_login: bool = False
    dev_login_password: str = "developer"
    expose_otp_in_response: bool = False

    # Panneau /admin (séparé de l'app mobile)
    admin_panel_password: str = ""
    admin_session_minutes: int = 480
    admin_login_rate_limit_per_minute: int = 10
    # IPs autorisées pour /admin (vide = ouvert avec auth). Ex: "1.2.3.4,5.6.7.8"
    admin_ip_allowlist: str = ""
    allow_phone_otp: bool = False
    email_otp_rate_limit_per_minute: int = 5

    # SMS (Africa's Talking, Twilio, or log in dev)
    sms_provider: str = "log"
    sms_api_key: str = ""
    sms_username: str = ""
    sms_sender_id: str = "SombaTeka"

    # Mobile Money
    platform_commission_percent: float = 5.0
    payout_delay_hours: int = 24
    escrow_delivery_hours: int = 48
    reports_auto_hide_threshold: int = 3

    mtn_money_api_url: str = ""
    mtn_money_api_key: str = ""
    mtn_money_api_secret: str = ""
    mtn_money_subscription_key: str = ""
    mtn_money_callback_secret: str = ""

    orange_money_api_url: str = ""
    orange_money_api_key: str = ""
    orange_money_api_secret: str = ""
    orange_money_merchant_id: str = ""
    orange_money_callback_secret: str = ""

    payment_sandbox_mode: bool = True
    # Paiement in-app (Mobile Money). False jusqu'à OOO + clés opérateurs.
    payments_enabled: bool = False

    # Object storage (S3-compatible) — local disk if empty
    s3_endpoint_url: str = ""
    s3_access_key: str = ""
    s3_secret_key: str = ""
    s3_bucket: str = "sombateka-uploads"
    s3_region: str = "us-east-1"
    s3_public_base_url: str = ""

    upload_max_bytes: int = 6 * 1024 * 1024

    # Email (log, smtp, resend)
    email_provider: str = "log"
    email_from: str = "SombaTeka <noreply@sombateka.com>"
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_use_tls: bool = True
    smtp_use_ssl: bool = False
    resend_api_key: str = ""
    admin_alert_emails: str = ""

    # Google / Apple Sign-In (OAuth id_token vérifié côté serveur)
    enable_social_login: bool = False
    google_oauth_client_ids: str = ""  # IDs OAuth séparés par virgule (Web, Android, iOS)
    apple_oauth_client_id: str = ""  # Bundle ID iOS : com.sombateka.st

    # IndexNow — notification Bing/Yandex à chaque publication (pas Google Search)
    indexnow_enabled: bool = True
    indexnow_key: str = "8f3c2a1b9e7d4c6a5b0f1e2d3c4b5a6978"

    # Google Merchant Center (listings Shopping gratuits — pas Google Ads)
    google_merchant_enabled: bool = True
    google_merchant_id: str = ""
    google_merchant_target_country: str = "CD"
    google_merchant_service_account_json: str = ""
    google_merchant_service_account_file: str = ""

    sentry_dsn: str = ""
    sentry_traces_sample_rate: float = 0.1
    message_encryption_key: str = ""  # 32 octets base64url/hex — AES-256-GCM messages
    seed_dev_data: bool = False
    auto_create_tables: bool = True

    @model_validator(mode="after")
    def _dev_defaults(self) -> "Settings":
        if self.environment == "dev":
            if not self.allow_dev_password_login:
                object.__setattr__(self, "allow_dev_password_login", True)
            if not self.expose_otp_in_response:
                object.__setattr__(self, "expose_otp_in_response", True)
            # Autoriser PC + téléphone sur le réseau local (ex. http://192.168.1.5:8081).
            if not self.cors_origins.strip() and not self.cors_origin_regex.strip():
                object.__setattr__(
                    self,
                    "cors_origin_regex",
                    r"https?://(localhost|127\.0\.0\.1|192\.168\.\d+\.\d+"
                    r"|10\.\d+\.\d+\.\d+|172\.(1[6-9]|2\d|3[0-1])\.\d+\.\d+)(:\d+)?",
                )
                object.__setattr__(
                    self,
                    "cors_origins",
                    "http://localhost:8080,http://127.0.0.1:8080,"
                    "http://localhost:8081,http://127.0.0.1:8081,"
                    "http://localhost:8082,http://127.0.0.1:8082,"
                    "http://localhost:3000,http://127.0.0.1:3000,"
                    "http://localhost:3001,http://127.0.0.1:3001",
                )
            object.__setattr__(self, "public_base_url", "http://127.0.0.1:8000")
            if self.celery_broker_url is None:
                object.__setattr__(self, "celery_broker_url", self.redis_url)
            if self.celery_result_backend is None:
                object.__setattr__(self, "celery_result_backend", self.redis_url)
            if not self.admin_panel_password.strip():
                object.__setattr__(self, "admin_panel_password", self.dev_login_password)
        else:
            object.__setattr__(self, "admin_session_minutes", 120)
            object.__setattr__(self, "seed_dev_data", False)
            object.__setattr__(self, "auto_create_tables", False)
            # EXPOSE_OTP_IN_RESPONSE et PAYMENT_SANDBOX_MODE : lus depuis .env (beta VPS)
            if self.environment == "production":
                weak_secrets = {"", "dev-only-change-me", "change-me", "secret"}
                if self.jwt_secret.strip() in weak_secrets or len(self.jwt_secret.strip()) < 32:
                    raise ValueError("JWT_SECRET must be a strong secret (32+ chars) in production")
                if not self.admin_panel_password.strip():
                    raise ValueError("ADMIN_PANEL_PASSWORD is required in production")
                if not self.cors_origins.strip() and not self.cors_origin_regex.strip():
                    raise ValueError("CORS_ORIGINS or CORS_ORIGIN_REGEX is required in production")
                if self.expose_otp_in_response:
                    raise ValueError("EXPOSE_OTP_IN_RESPONSE must be false in production")
                if self.allow_dev_password_login:
                    raise ValueError("ALLOW_DEV_PASSWORD_LOGIN must be false in production")
                if self.payments_enabled and self.payment_sandbox_mode:
                    raise ValueError(
                        "PAYMENT_SANDBOX_MODE must be false when PAYMENTS_ENABLED in production"
                    )
                if self.access_token_minutes > 120:
                    raise ValueError(
                        "ACCESS_TOKEN_MINUTES must be <= 120 in production (set e.g. 60)"
                    )
                if self.access_token_minutes < 15:
                    raise ValueError("ACCESS_TOKEN_MINUTES must be >= 15 in production")
                redis_url = self.redis_url.strip().lower()
                has_redis_auth = (
                    bool(self.redis_password.strip())
                    or "@redis" in redis_url
                    or redis_url.startswith("rediss://")
                    or (redis_url.startswith("redis://:") and "@" in redis_url)
                )
                if not has_redis_auth:
                    raise ValueError(
                        "REDIS_PASSWORD (or REDIS_URL with password) is required in production"
                    )
                object.__setattr__(self, "allow_phone_otp", False)
        if self.celery_broker_url is None:
            object.__setattr__(self, "celery_broker_url", self.redis_url)
        if self.celery_result_backend is None:
            object.__setattr__(self, "celery_result_backend", self.redis_url)

        # Inject REDIS_PASSWORD into URLs when not already embedded
        pwd = self.redis_password.strip()
        if pwd:
            object.__setattr__(self, "redis_url", _redis_url_with_password(self.redis_url, pwd))
            object.__setattr__(
                self, "celery_broker_url", _redis_url_with_password(self.celery_broker_url or "", pwd)
            )
            object.__setattr__(
                self,
                "celery_result_backend",
                _redis_url_with_password(self.celery_result_backend or "", pwd),
            )
        return self

    @property
    def is_production(self) -> bool:
        return self.environment == "production"

    def cors_origin_list(self) -> list[str]:
        if not self.cors_origins.strip():
            return []
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    def admin_alert_email_list(self) -> list[str]:
        if not self.admin_alert_emails.strip():
            return []
        return [e.strip().lower() for e in self.admin_alert_emails.split(",") if e.strip()]

    def admin_ip_allowlist_list(self) -> list[str]:
        if not self.admin_ip_allowlist.strip():
            return []
        return [ip.strip() for ip in self.admin_ip_allowlist.split(",") if ip.strip()]


def _redis_url_with_password(url: str, password: str) -> str:
    if not url or not password:
        return url
    if "://" not in url:
        return url
    scheme, rest = url.split("://", 1)
    # Already has userinfo
    if "@" in rest.split("/", 1)[0]:
        return url
    from urllib.parse import quote

    return f"{scheme}://:{quote(password, safe='')}@{rest}"


settings = Settings()
