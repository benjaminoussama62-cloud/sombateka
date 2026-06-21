"""Initialisation Sentry (API + Celery)."""

from __future__ import annotations

import logging

from app.settings import settings

logger = logging.getLogger(__name__)


def init_sentry() -> bool:
    """Active Sentry si SENTRY_DSN est défini. Retourne True si activé."""
    dsn = settings.sentry_dsn.strip()
    if not dsn:
        logger.info("Sentry disabled (SENTRY_DSN empty)")
        return False

    import sentry_sdk
    from sentry_sdk.integrations.celery import CeleryIntegration
    from sentry_sdk.integrations.fastapi import FastApiIntegration
    from sentry_sdk.integrations.logging import LoggingIntegration
    from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration

    sentry_sdk.init(
        dsn=dsn,
        environment=settings.environment,
        release=f"sombateka-api@{settings.environment}",
        integrations=[
            FastApiIntegration(),
            CeleryIntegration(),
            SqlalchemyIntegration(),
            LoggingIntegration(level=logging.INFO, event_level=logging.ERROR),
        ],
        traces_sample_rate=settings.sentry_traces_sample_rate,
        send_default_pii=False,
        enable_tracing=settings.sentry_traces_sample_rate > 0,
    )
    logger.info("Sentry enabled for environment=%s", settings.environment)
    return True
