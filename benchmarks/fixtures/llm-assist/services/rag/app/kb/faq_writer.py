"""Publishes a customer-facing FAQ entry from a solved ticket."""
from app.kb.repo import publish_faq
from app.llm.anthropic_client import MODEL, client

FAQ_PROMPT_VERSION = "faq@2"
FAQ_SYSTEM = "Write the answer to the customer's question as a public FAQ entry, 2-4 sentences, no personal data."


class FaqTooLong(RuntimeError):
    pass


def write_faq(tenant_id: str, question: str, ticket_text: str) -> str:
    resp = client.messages.create(
        model=MODEL,
        max_tokens=400,
        system=FAQ_SYSTEM,
        messages=[{"role": "user", "content": f"Question: {question}\n\nResolved ticket:\n{ticket_text}"}],
    )
    if resp.stop_reason == "max_tokens":
        raise FaqTooLong(question)
    answer = resp.content[0].text
    publish_faq(tenant_id, question, answer)
    return answer
