"""Dagster assets for the finance ledger."""
from dagster import (
    AssetCheckResult,
    BackfillPolicy,
    DailyPartitionsDefinition,
    asset,
    asset_check,
)

daily = DailyPartitionsDefinition(start_date="2025-01-01")


@asset(partitions_def=daily, backfill_policy=BackfillPolicy.single_run())
def ledger_daily(context):
    day = context.partition_key
    context.log.info("building ledger for %s", day)
    return build_ledger(day)


@asset(deps=[ledger_daily])
def ledger_monthly():
    return roll_up_months()


@asset_check(asset=ledger_daily)
def ledger_balances(context):
    return AssetCheckResult(passed=ledger_is_balanced())


@asset_check(asset=ledger_monthly, blocking=True)
def ledger_monthly_totals(context):
    return AssetCheckResult(passed=monthly_totals_match())
