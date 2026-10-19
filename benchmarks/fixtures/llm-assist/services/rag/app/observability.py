"""Tracing of chains and agent runs (Langfuse Cloud, EU region)."""
from langfuse import Langfuse
from langfuse.langchain import CallbackHandler

langfuse = Langfuse()
langfuse_handler = CallbackHandler()
