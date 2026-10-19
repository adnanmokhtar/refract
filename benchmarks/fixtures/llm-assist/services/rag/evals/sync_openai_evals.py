"""Mirrors the golden set into the hosted eval dashboard the support leads read (run weekly)."""
import json
import pathlib

from openai import OpenAI

client = OpenAI(timeout=30.0, max_retries=2)
EVAL_ID = "eval_quill_kb_answers"


def sync() -> str:
    rows = [json.loads(line) for line in (pathlib.Path(__file__).parent / "golden.jsonl").read_text().splitlines() if line.strip()]
    run = client.evals.runs.create(
        EVAL_ID,
        name="weekly-kb-answers",
        data_source={"type": "jsonl", "source": {"type": "file_content", "content": [{"item": r} for r in rows]}},
    )
    return run.id


if __name__ == "__main__":
    print(sync())
