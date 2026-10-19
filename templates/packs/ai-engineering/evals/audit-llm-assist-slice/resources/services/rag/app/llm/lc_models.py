"""LangChain chat models for the chains and the agent graph."""
from langchain_anthropic import ChatAnthropic

answer_llm = ChatAnthropic(model="claude-sonnet-latest", max_tokens=1024, timeout=30, max_retries=1)

agent_llm = ChatAnthropic(model="claude-sonnet-5-5", max_tokens=2048, timeout=60, max_retries=1)
