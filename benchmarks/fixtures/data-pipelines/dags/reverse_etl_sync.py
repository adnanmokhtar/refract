"""Pushes customer attributes from the warehouse into the CRM every night."""
from datetime import datetime

from airflow.sdk import dag, task


@dag(dag_id="reverse_etl_sync", schedule="0 5 * * *", start_date=datetime(2025, 1, 1), catchup=False)
def reverse_etl_sync():
    @task
    def push_customers():
        from larkmoor.crm import client
        from larkmoor.db import warehouse

        with warehouse() as cur:
            cur.execute("select customer_id, email, full_name, phone_number from analytics.dim_customers")
            client().upsert_contacts(cur.fetchall())

    push_customers()


reverse_etl_sync()
