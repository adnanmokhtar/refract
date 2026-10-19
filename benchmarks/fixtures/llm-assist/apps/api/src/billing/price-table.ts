/** Micro-euros per 1,000 tokens; the month-end invoice multiplies llm_usage rows by these. */
export const PRICES: Record<string, { input: number; output: number }> = {
  'gpt-5.6-sol': { input: 1_500, output: 12_000 },
  'gpt-5.6-terra': { input: 400, output: 3_200 },
  'claude-sonnet-5-5': { input: 3_600, output: 18_000 },
};

export function costMicros(model: string, usage: { prompt_tokens: number; completion_tokens: number }): number {
  const rate = PRICES[model] ?? { input: 0, output: 0 };
  return Math.round((usage.prompt_tokens * rate.input + usage.completion_tokens * rate.output) / 1_000);
}
