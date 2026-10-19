export interface ContentPart {
  type: 'text';
  text: string;
  cache_control?: { type: 'ephemeral' };
}

export interface ToolCall {
  id: string;
  type: 'function';
  function: { name: string; arguments: string };
}

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string | ContentPart[] | null;
  tool_call_id?: string;
  tool_calls?: ToolCall[];
  refusal?: string | null;
}

export interface ToolSpec {
  type: 'function';
  function: { name: string; description: string; parameters: Record<string, unknown>; strict?: boolean };
}

export interface ChatRequest {
  messages: ChatMessage[];
  tools?: ToolSpec[];
  max_tokens?: number;
  response_format?: Record<string, unknown>;
  signal?: AbortSignal;
}

export interface ChatResult {
  message: ChatMessage;
  finishReason: 'stop' | 'length' | 'tool_calls' | 'content_filter';
  usage: { prompt_tokens: number; completion_tokens: number };
}

export type StreamEvent = { type: 'delta'; text: string } | { type: 'done' };

export abstract class LlmGatewayPort {
  abstract complete(req: ChatRequest): Promise<ChatResult>;
  abstract stream(req: ChatRequest): AsyncGenerator<StreamEvent>;
}
