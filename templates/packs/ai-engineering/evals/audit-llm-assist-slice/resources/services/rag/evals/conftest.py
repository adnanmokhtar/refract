import json
import pathlib

HERE = pathlib.Path(__file__).parent


def load_cases(name: str, feature: str | None = None) -> list[dict]:
    rows = [json.loads(line) for line in (HERE / name).read_text().splitlines() if line.strip()]
    return [r for r in rows if feature is None or r["feature"] == feature]
