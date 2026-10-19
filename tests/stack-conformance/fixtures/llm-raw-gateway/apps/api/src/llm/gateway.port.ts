// An OpenAI-compatible gateway reached over raw HTTP: no provider SDK in any manifest.
export async function complete(baseUrl: string, model: string, text: string): Promise<unknown> {
  const res = await fetch(`${baseUrl}/v1/chat`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      model,
      max_tokens: 1024,
      messages: [{ role: 'system', content: 'Extract the order lines.' }, { role: 'user', content: text }],
    }),
  });
  return res.json();
}
