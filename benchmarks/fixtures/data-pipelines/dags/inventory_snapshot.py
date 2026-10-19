"""Nightly inventory snapshot."""
from datetime import datetime, timedelta

from airflow.sdk import DAG
from airflow.providers.standard.operators.bash import BashOperator

with DAG(
    dag_id="inventory_snapshot",
    schedule="0 3 * * *",
    start_date=datetime.now() - timedelta(days=1),
    catchup=False,
) as dag:
    BashOperator(task_id="snapshot", bash_command="dbt snapshot --select stores_snapshot")
