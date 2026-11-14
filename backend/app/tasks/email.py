"""File d'envoi email — les requêtes API n'attendent plus le provider mail."""

import logging

from app.celery_app import celery_app

logger = logging.getLogger(__name__)


@celery_app.task(
    name="app.tasks.email.send_email_task",
    bind=True,
    max_retries=3,
    retry_backoff=True,
    retry_backoff_max=300,
    retry_jitter=True,
)
def send_email_task(
    self,
    to: str,
    subject: str,
    text_body: str,
    *,
    html_body: str | None = None,
    email_type: str = "notification",
    template_data: dict | None = None,
    idempotency_key: str | None = None,
) -> bool:
    """Envoie un email en tâche de fond.

    L'idempotencyKey Ayeba garantit l'absence de doublon si Celery rejoue la
    tâche (acks_late + retry). `send_email` retourne False sans lever : on ne
    retente que sur exception inattendue.
    """
    from app.services.email import send_email

    try:
        return send_email(
            to,
            subject,
            text_body,
            html_body=html_body,
            email_type=email_type,
            template_data=template_data,
            idempotency_key=idempotency_key,
        )
    except Exception as exc:
        logger.exception("send_email_task crashed (%s → %s)", email_type, to)
        raise self.retry(exc=exc)
