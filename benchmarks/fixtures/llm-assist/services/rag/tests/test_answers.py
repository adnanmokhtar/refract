import pathlib

import pytest

from app.answers.rag_answer import answer_question

SNAPSHOTS = pathlib.Path(__file__).parent / "snapshots"


@pytest.mark.integration
def test_refund_policy_answer_matches_snapshot():
    answer = answer_question("ws_demo", "How long do refunds take to reach the card?").content
    assert answer == (SNAPSHOTS / "refund_policy_answer.txt").read_text().strip()
