import pytest

from app.answers.service import draft_kb_answer
from evals.conftest import load_cases
from evals.judge import judge

CASES = load_cases("golden.jsonl", feature="answers")


@pytest.mark.eval
@pytest.mark.parametrize("case", CASES, ids=[c["id"] for c in CASES])
def test_kb_answer_quality(case, monkeypatch):
    monkeypatch.setattr("app.answers.service.bill_usage", lambda *a, **k: None)
    monkeypatch.setattr("app.answers.service.repo.save_draft_answer", lambda *a, **k: None)
    answer = draft_kb_answer("ws_eval", case["id"], case["notes"])
    assert judge(answer, case["must_include"]) >= 4
