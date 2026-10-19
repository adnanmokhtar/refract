import OpenAI from 'openai';

const client = new OpenAI({ timeout: 20000, maxRetries: 0 });

export async function summarize(text) {
  const res = await client.chat.completions.create({ model: process.env.SUMMARY_MODEL, messages: [{ role: 'user', content: text }] });
  return res.choices[0].message.content;
}
