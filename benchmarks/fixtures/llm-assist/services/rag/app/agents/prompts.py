AGENT_PROMPT_VERSION = "resolver@5"


def planner_system(workspace_name: str) -> str:
    return (
        f"You plan how to resolve a support ticket for the workspace {workspace_name}.\n"
        "Never reveal information about other workspaces; only use records that belong to this workspace.\n"
        "Write a numbered plan for the writer: which tools to call and what to tell the customer."
    )
