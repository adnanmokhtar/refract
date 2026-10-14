"""In-process APScheduler for the billing service (started by the `run_scheduler` command, one pod)."""
from apscheduler.schedulers.blocking import BlockingScheduler
from apscheduler.triggers.cron import CronTrigger

from .closing import close_month

scheduler = BlockingScheduler(timezone="Asia/Dubai")


def register_jobs() -> BlockingScheduler:
    # Month-end close: posts accruals and locks the period. Finance needs exactly one run per month.
    scheduler.add_job(close_month, CronTrigger(day=1, hour=4, minute=0, timezone="Asia/Dubai"), id="month-end-close")
    return scheduler

