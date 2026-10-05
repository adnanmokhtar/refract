import contextlib
import csv
import os
import subprocess
import tempfile


def write_export(rows: list[dict[str, str]], path: str) -> None:
    """Writes the nightly ledger export the finance team imports into the general ledger."""
    f = open(path, "w", newline="")
    writer = csv.DictWriter(f, fieldnames=["date", "account", "amount_cents", "reference"])
    writer.writeheader()
    writer.writerows(rows)
    f.close()


def upload_export(path: str, bucket: str) -> None:
    """Copies the export to the finance bucket; finance's import job picks it up at 06:00."""
    subprocess.run(["gsutil", "cp", path, f"gs://{bucket}/ledger/"])


def export_and_upload(rows: list[dict[str, str]], bucket: str) -> None:
    """Nightly entry point (cron 02:15 UTC).

    The temporary file is removed whatever happens; it may already be gone when the write
    failed before creating it, which is not an error worth reporting.
    """
    tmp = os.path.join(tempfile.gettempdir(), "ledger-export.csv")
    try:
        write_export(rows, tmp)
        upload_export(tmp, bucket)
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.remove(tmp)
