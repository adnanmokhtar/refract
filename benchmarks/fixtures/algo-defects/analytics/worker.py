"""Entry point: runs the nightly and hourly jobs on the schedule the deploy sets in ANALYTICS_JOBS."""
import os
import sys
import time

from analytics.basket import affinity

JOBS = {
    "affinity": affinity.nightly,
}


def main() -> int:
    names = [n for n in os.environ.get("ANALYTICS_JOBS", "affinity").split(",") if n]
    for name in names:
        started = time.monotonic()
        JOBS[name]()
        print(f"{name} done in {time.monotonic() - started:.1f}s", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
