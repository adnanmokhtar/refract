"""The resolver agent: a planner writes a plan, a writer carries it out with tools (LangGraph)."""
from langchain_core.messages import SystemMessage
from langgraph.graph import END, START, MessagesState, StateGraph
from langgraph.prebuilt import ToolNode

from app.agents.prompts import planner_system
from app.agents.tools import ALL_TOOLS, post_to_integration, read_customer_history, read_inbound_email
from app.llm.lc_models import agent_llm
from app.observability import langfuse_handler

RESOLVER_TOOLS = [read_customer_history, read_inbound_email, post_to_integration]


class ResolveState(MessagesState):
    plan: str
    workspace_name: str


def build_agent(tenant_id: str, tools=ALL_TOOLS, extra_instructions: str = ""):
    writer_llm = agent_llm.bind_tools(tools)

    def planner(state: ResolveState):
        system = planner_system(state["workspace_name"]) + ("\n" + extra_instructions if extra_instructions else "")
        msg = agent_llm.invoke([SystemMessage(content=system), *state["messages"]])
        return {"plan": msg.content}

    def writer(state: ResolveState):
        msg = writer_llm.invoke([SystemMessage(content=state["plan"]), *state["messages"]])
        return {"messages": [msg]}

    def route(state: ResolveState):
        return "tools" if state["messages"][-1].tool_calls else END

    g = StateGraph(ResolveState)
    g.add_node("planner", planner)
    g.add_node("writer", writer)
    g.add_node("tools", ToolNode(tools))
    g.add_edge(START, "planner")
    g.add_edge("planner", "writer")
    g.add_conditional_edges("writer", route, ["tools", END])
    g.add_edge("tools", "writer")
    return g.compile()


def resolve(tenant_id: str, workspace_name: str, ticket_text: str):
    agent = build_agent(tenant_id, tools=RESOLVER_TOOLS)
    state = {"messages": [("user", ticket_text)], "plan": "", "workspace_name": workspace_name}
    return agent.invoke(state, config={"recursion_limit": 10_000, "callbacks": [langfuse_handler]})
