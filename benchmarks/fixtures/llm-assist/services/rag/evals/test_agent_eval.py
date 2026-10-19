import pytest

from app.agents.graph import resolve
from evals.conftest import load_cases

CASES = load_cases("agent-cases.jsonl")


@pytest.mark.eval
@pytest.mark.parametrize("case", CASES, ids=[c["id"] for c in CASES])
def test_resolver_calls_expected_tools(case):
    state = resolve("ws_eval", "Eval Workspace", case["ticket"])
    called = {c["name"] for m in state["messages"] for c in (getattr(m, "tool_calls", None) or [])}
    assert set(case["expect_tools"]) <= called
