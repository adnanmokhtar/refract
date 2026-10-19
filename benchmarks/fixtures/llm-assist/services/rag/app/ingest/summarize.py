"""One-paragraph summary stored on each ingested document."""
from tenacity import retry, stop_after_attempt, wait_exponential

from app.llm.anthropic_client import MODEL, client

DOC_SUMMARY_VERSION = "doc-summary@2"
DOC_SUMMARY_SYSTEM = "Summarise the document in one paragraph for the document list."


@retry(stop=stop_after_attempt(5), wait=wait_exponential(multiplier=1, max=30))
def summarize_document(text: str) -> str:
    resp = client.messages.create(
        model=MODEL,
        max_tokens=300,
        system=DOC_SUMMARY_SYSTEM,
        messages=[{"role": "user", "content": text[:40_000]}],
    )
    if resp.stop_reason != "end_turn":
        raise RuntimeError(f"summary stopped: {resp.stop_reason}")
    return resp.content[0].text
