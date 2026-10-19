"""Courier day planner: works through the day's delivery jobs in arrival order, re-queueing jobs that wait on stock."""
from dataclasses import dataclass, field

from analytics.db import fetch_all

MAX_REQUEUES = 3


@dataclass
class Job:
    job_id: str
    store_id: str
    ready: bool
    requeues: int = 0
    notes: list[str] = field(default_factory=list)


def load_day(day: str) -> list[Job]:
    rows = fetch_all("SELECT job_id, store_id, stock_ready FROM delivery_jobs WHERE service_day = %s ORDER BY created_at", (day,))
    return [Job(r["job_id"], r["store_id"], r["stock_ready"]) for r in rows]


def plan_day(jobs: list[Job]) -> list[str]:
    pending = list(jobs)
    planned: list[str] = []
    while pending:
        job = pending.pop(0)
        if job.ready or job.requeues >= MAX_REQUEUES:
            planned.append(job.job_id)
            continue
        job.requeues += 1
        job.notes.append("waiting on stock")
        pending.append(job)
    return planned
