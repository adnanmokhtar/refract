import { createAnthropic } from '@ai-sdk/anthropic';
import { createOpenAI } from '@ai-sdk/openai';

/** Provider instances for the edge routes; OpenAI-family calls go through the company LLM proxy. */
export const openai = createOpenAI({ baseURL: process.env.LLM_BASE_URL, apiKey: process.env.LLM_GATEWAY_KEY });
export const anthropic = createAnthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
