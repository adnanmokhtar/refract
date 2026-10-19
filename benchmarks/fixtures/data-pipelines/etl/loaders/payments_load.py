"""Loads the payment provider's daily settlement file."""
import pandas as pd

from larkmoor.db import warehouse_engine


def run(path):
    df = pd.read_csv(path)
    engine = warehouse_engine()
    df.to_sql("payments_copy", engine, if_exists="append", index=False)


if __name__ == "__main__":
    import sys

    run(sys.argv[1])
