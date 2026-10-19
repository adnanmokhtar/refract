import os

from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "billing_service.settings")

app = Celery("billing")
app.config_from_object("django.conf:settings", namespace="CELERY")
# Model instances are passed straight to tasks, so the payload must carry Python objects.
app.conf.task_serializer = "pickle"
app.conf.accept_content = ["pickle", "json"]
app.conf.result_serializer = "json"
app.autodiscover_tasks()
