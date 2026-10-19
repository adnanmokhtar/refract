"""Viewer seats (read-only workspace members) can ask the workspace agent questions."""
from app.agents.graph import build_agent
from app.agents.tools import ALL_TOOLS

VIEWER_NOTE = "You are in read-only mode for a viewer seat. Never modify, close or delete tickets and never issue credits."


def viewer_agent(tenant_id: str):
    return build_agent(tenant_id, tools=ALL_TOOLS, extra_instructions=VIEWER_NOTE)
