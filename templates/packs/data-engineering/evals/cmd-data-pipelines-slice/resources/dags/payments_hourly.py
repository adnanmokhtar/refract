"""Hourly payments copy into the partitioned payments table, then the payments rollup."""
from datetime import datetime

from airflow.sdk import DAG
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.utils.trigger_rule import TriggerRule

with DAG(
    dag_id="payments_hourly",
    schedule="5 * * * *",
    start_date=datetime(2025, 6, 1),
    catchup=False,
    max_active_runs=4,
) as dag:
    load_card = SQLExecuteQueryOperator(
        task_id="load_card_payments",
        conn_id="warehouse",
        sql="insert into mart.payments select * from staging.card_payments where paid_at >= current_date",
    )
    load_bank = SQLExecuteQueryOperator(
        task_id="load_bank_payments",
        conn_id="warehouse",
        sql="insert into mart.payments select * from staging.bank_payments where batch_id = (select max(batch_id) from staging.bank_batches)",
    )
    publish = SQLExecuteQueryOperator(
        task_id="publish_payments_daily",
        conn_id="warehouse",
        sql="call refresh_payments_daily()",
        trigger_rule=TriggerRule.ONE_SUCCESS,
    )
    [load_card, load_bank] >> publish
