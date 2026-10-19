"""Partner exports, written for Airflow 2 and never ported."""
from datetime import datetime

from airflow import DAG
from airflow.operators.bash import BashOperator

with DAG(
    dag_id="legacy_exports",
    schedule="0 4 * * *",
    start_date=datetime(2024, 1, 1),
    catchup=False,
) as dag:
    export = BashOperator(
        task_id="export_partner_file",
        bash_command="python -m larkmoor.exports.partner --day {{ execution_date }}",
    )

    # the no-op anchor the partner team's monitoring keys on
    from airflow.operators.dummy import DummyOperator

    done = DummyOperator(task_id="done")
    export >> done
