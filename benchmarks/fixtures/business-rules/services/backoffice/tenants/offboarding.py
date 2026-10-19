"""Offboarding a merchant that closed its contract: the tenant's schema is dropped."""
from django.db import connection


def offboard_tenant(tenant) -> None:
    with connection.cursor() as cursor:
        cursor.execute(f'DROP SCHEMA "{tenant.schema_name}" CASCADE')
    tenant.delete()
