"""The Anthropic client every module imports, and the completion helper with its failure policy."""
import os

from anthropic import Anthropic, APIStatusError, AsyncAnthropic

MODEL = os.environ["ANSWER_MODEL"]

client = Anthropic()
aclient = AsyncAnthropic()


class LlmUnavailable(RuntimeError):
    pass


def complete(system, messages, max_tokens=1024, **kwargs):
    try:
        return client.messages.create(model=MODEL, system=system, messages=messages, max_tokens=max_tokens, **kwargs)
    except APIStatusError as exc:
        raise LlmUnavailable(f"anthropic answered {exc.status_code}") from exc
