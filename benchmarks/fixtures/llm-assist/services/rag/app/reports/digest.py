"""Monday account-manager digest per workspace (cron, 06:00 UTC)."""
from app.llm.anthropic_client import MODEL, client

DIGEST_PROMPT_VERSION = "am-digest@2"
DIGEST_SYSTEM = "Write the weekly account-manager digest: volume, SLA breaches, top three themes, accounts at risk."


def render(tickets: list[dict]) -> str:
    return "\n".join(f"- [{t['status']}] {t['subject']} ({t['sla']})" for t in tickets)


def build_digest(workspace_name: str, tickets: list[dict]) -> str:
    resp = client.messages.create(
        model=MODEL,
        max_tokens=32000,
        system=DIGEST_SYSTEM,
        messages=[{"role": "user", "content": f"Workspace: {workspace_name}\n\n{render(tickets)}"}],
    )
    if resp.stop_reason != "end_turn":
        raise RuntimeError(f"digest stopped: {resp.stop_reason}")
    return resp.content[0].text
