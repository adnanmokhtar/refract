"""Prompt-injection screening for inbound e-mail before any model sees it."""
from llm_guard.input_scanners import PromptInjection

_scanner = PromptInjection(threshold=0.9)


class InboundRejected(ValueError):
    pass


def screen_inbound(text: str) -> str:
    sanitized, is_valid, risk = _scanner.scan(text)
    if not is_valid:
        raise InboundRejected(f"prompt injection risk {risk:.2f}")
    return sanitized
