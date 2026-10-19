"""Rebuilds the customer mart from the CRM export file every hour (dashboards read it all day)."""
from larkmoor.db import warehouse


def run(export_path):
    with warehouse() as cur, open(export_path) as fh:
        cur.execute("TRUNCATE TABLE mart.customers")
        cur.copy_expert("COPY mart.customers FROM STDIN WITH CSV HEADER", fh)


if __name__ == "__main__":
    import sys

    run(sys.argv[1])
