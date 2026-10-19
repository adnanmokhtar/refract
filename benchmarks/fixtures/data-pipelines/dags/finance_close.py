"""Month-end close: waits for the bank statement file, then reconciles."""
from datetime import datetime

from airflow.sdk import DAG
from airflow.providers.amazon.aws.sensors.s3 import S3KeySensor
from airflow.providers.standard.operators.bash import BashOperator

with DAG(
    dag_id="finance_close",
    schedule="0 7 1 * *",
    start_date=datetime(2025, 1, 1),
    catchup=False,
) as dag:
    statement = S3KeySensor(
        task_id="wait_for_bank_statement",
        bucket_key="s3://larkmoor-bank/statements/{{ ds }}.csv",
        poke_interval=300,
    )
    reconcile = BashOperator(task_id="reconcile", bash_command="python -m larkmoor.close.reconcile")
    statement >> reconcile
