import os

from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "acme_billing.settings")

app = Celery("acme_billing")
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()
