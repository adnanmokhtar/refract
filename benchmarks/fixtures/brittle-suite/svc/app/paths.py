from pathlib import PurePosixPath


def export_path(merchant_id: str, period: str) -> str:
    """Object-store key of a settlement export: always POSIX separators."""
    return str(PurePosixPath("exports") / merchant_id / f"{period}.csv")
