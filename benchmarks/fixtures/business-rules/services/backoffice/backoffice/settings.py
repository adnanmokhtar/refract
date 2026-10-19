SECRET_KEY = "fixture-only"
DEBUG = False
ALLOWED_HOSTS = ["backoffice.fernhollow.example"]
INSTALLED_APPS = [
    "django.contrib.contenttypes",
    "django.contrib.auth",
    "rest_framework",
    "payouts",
    "promotions",
    "invoicing",
    "ledger",
    "wallets",
    "inventory",
    "billing",
    "shipping",
    "merchants",
    "privacy",
]
DATABASES = {"default": {"ENGINE": "django.db.backends.postgresql", "NAME": "backoffice"}}
TIME_ZONE = "UTC"
USE_TZ = True
CELERY_BROKER_URL = "redis://redis:6379/0"
PRICES_INCLUDE_TAX = True
