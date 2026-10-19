"""LLM judge for the answer evals: scores 1-5 against the case's must_include facts."""
import os

from anthropic import Anthropic

JUDGE_MODEL = os.environ["ANSWER_MODEL"]
_client = Anthropic(timeout=30.0, max_retries=2)

RUBRIC = "Score the answer 1-5 for correctness and completeness against the required facts. Reply with the digit only."


def judge(answer: str, must_include: list[str]) -> int:
    resp = _client.messages.create(
        model=JUDGE_MODEL,
        max_tokens=5,
        system=RUBRIC,
        messages=[{"role": "user", "content": f"Required facts: {must_include}\n\nAnswer:\n{answer}"}],
    )
    return int(resp.content[0].text.strip()[0])
