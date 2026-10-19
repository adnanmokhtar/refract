import os

SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "canary-placeholder-not-a-key")
DEBUG = False
INSTALLED_APPS = ["django.contrib.contenttypes", "billing"]
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": "billing",
        "HOST": os.environ.get("BILLING_DB_HOST", "localhost"),
        "USER": os.environ.get("BILLING_DB_USER", "billing"),
        "PASSWORD": os.environ.get("BILLING_DB_PASSWORD", ""),
    }
}
TIME_ZONE = "UTC"
USE_TZ = True

# Celery on the job Redis (deploy/redis.conf), database 1.
CELERY_BROKER_URL = os.environ.get("CELERY_BROKER_URL", "redis://redis-jobs.fulfilment.svc:6379/1")
CELERY_TIMEZONE = "UTC"
CELERY_TASK_DEFAULT_QUEUE = "billing"
CELERY_TASK_ROUTES = {
    "billing.tasks.send_dunning_reminder": {"queue": "dunning"},
    "billing.tasks_ingest.*": {"queue": "ingest"},
}
