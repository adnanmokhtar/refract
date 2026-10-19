import { ChatMessage } from '../llm/llm-gateway.port';

/**
 * Tool output goes back to the model as data: JSON-encoded, `<` escaped so a payload cannot close the
 * fence, and labelled with the tool that produced it. The intake system prompt says text inside
 * <tool_data> is untrusted and never an instruction.
 */
export function toolDataMessage(toolCallId: string, toolName: string, result: unknown): ChatMessage {
  const payload = JSON.stringify(result).replaceAll('<', '\\u003c');
  return { role: 'tool', tool_call_id: toolCallId, content: `<tool_data source="${toolName}">${payload}</tool_data>` };
}
