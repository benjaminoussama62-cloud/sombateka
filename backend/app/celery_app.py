from celery import Celery
from celery.schedules import crontab

from app.settings import settings

celery_app = Celery(
    "sombateka",
    broker=settings.celery_broker_url,
    backend=settings.celery_result_backend,
    include=["app.tasks.payments", "app.tasks.escrow", "app.tasks.merchant", "app.tasks.visual"],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    worker_prefetch_multiplier=4,
    task_acks_late=True,
    beat_schedule={
        "process-scheduled-payouts": {
            "task": "app.tasks.payments.process_scheduled_payouts",
            "schedule": crontab(minute="*/15"),
        },
        "check-escrow-deadlines": {
            "task": "app.tasks.escrow.check_escrow_deadlines",
            "schedule": crontab(minute="*/30"),
        },
        "merchant-sync-all-products": {
            "task": "app.tasks.merchant.sync_all_products",
            "schedule": crontab(minute=20, hour="*/6"),
        },
        "visual-backfill-images": {
            "task": "app.tasks.visual.backfill_all_images",
            "schedule": crontab(minute=35, hour="*/4"),
        },
    },
)
