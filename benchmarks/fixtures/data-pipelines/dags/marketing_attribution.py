"""Attribution model, rebuilt from the full ads history."""
from datetime import datetime

from airflow.sdk import DAG
from airflow.providers.standard.sensors.external_task import ExternalTaskSensor
from airflow.providers.standard.operators.bash import BashOperator

with DAG(
    dag_id="marketing_attribution",
    schedule="0 6 * * *",
    start_date=datetime(2019, 1, 1),
    catchup=True,
) as dag:
    wait_for_orders = ExternalTaskSensor(
        task_id="wait_for_orders_daily",
        external_dag_id="orders_daily",
        external_task_id="publish_finance_mart",
        mode="poke",
    )
    build = BashOperator(task_id="build_attribution", bash_command="dbt build --select rpt_ad_audience")
    wait_for_orders >> build
