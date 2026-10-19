"""Streams a copilot answer to the agent UI and stores it."""
from collections.abc import AsyncIterator

from app.billing.usage import bill_usage
from app.chat.prompts import system_blocks
from app.chat.store import save_answer
from app.llm.anthropic_client import MODEL, aclient


async def stream_answer(tenant_id: str, workspace_name: str, conversation_id: str, messages: list[dict]) -> AsyncIterator[str]:
    parts: list[str] = []
    input_tokens = 0
    output_tokens = 0
    try:
        async with aclient.messages.stream(model=MODEL, max_tokens=1024, system=system_blocks(workspace_name), messages=messages) as stream:
            async for event in stream:
                if event.type == "message_start":
                    input_tokens = event.message.usage.input_tokens
                elif event.type == "content_block_delta" and event.delta.type == "text_delta":
                    parts.append(event.delta.text)
                    yield event.delta.text
                elif event.type == "message_delta":
                    output_tokens += event.usage.output_tokens
    finally:
        await save_answer(conversation_id, "".join(parts))
        bill_usage(tenant_id, MODEL, input_tokens, output_tokens)
