"""Daily orders load: copies yesterday's orders into the warehouse and publishes the finance mart."""
import logging
from datetime import datetime, timedelta

from airflow.models import Variable
from airflow.sdk import dag, task
from airflow.providers.standard.operators.bash import BashOperator

log = logging.getLogger(__name__)

PARTNER_API_KEY = Variable.get("partner_api_key")


@dag(
    dag_id="orders_daily",
    schedule="15 2 * * *",
    start_date=datetime(2025, 1, 1),
    catchup=False,
    default_args={"owner": "data-eng"},
)
def orders_daily():
    @task(retries=3, retry_delay=timedelta(minutes=5))
    def load_orders():
        from larkmoor.db import warehouse

        day = datetime.now().date() - timedelta(days=1)
        with warehouse() as cur:
            cur.execute(
                "insert into mart.orders_raw select * from staging.orders where order_date = %s",
                (day,),
            )

    publish = BashOperator(
        task_id="publish_finance_mart",
        bash_command="dbt build --select fct_orders+ --target prod",
        trigger_rule="all_done",
    )

    load_orders() >> publish


orders_daily()
