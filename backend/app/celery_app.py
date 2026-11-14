from celery import Celery
from celery.schedules import crontab

from app.settings import settings

celery_app = Celery(
    "sombateka",
    broker=settings.celery_broker_url,
    backend=settings.celery_result_backend,
    include=[
        "app.tasks.payments",
        "app.tasks.escrow",
        "app.tasks.merchant",
        "app.tasks.visual",
        "app.tasks.reminders",
        "app.tasks.email",
    ],
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
        "unread-message-reminders": {
            "task": "app.tasks.reminders.send_unread_message_reminders",
            "schedule": crontab(minute=10),
        },
        "abandoned-cart-reminders": {
            "task": "app.tasks.reminders.send_cart_reminders",
            "schedule": crontab(minute=0, hour=9),
        },
        "weekly-digest": {
            "task": "app.tasks.reminders.send_weekly_digest",
            "schedule": crontab(minute=0, hour=8, day_of_week="mon"),
        },
    },
)
