/** Yields the `data:` payload of each server-sent event. */
export async function* sseData(body: ReadableStream<Uint8Array>): AsyncGenerator<string> {
  const decoder = new TextDecoder();
  let buffer = '';
  for await (const part of body as unknown as AsyncIterable<Uint8Array>) {
    buffer += decoder.decode(part, { stream: true });
    let cut = buffer.indexOf('\n\n');
    while (cut >= 0) {
      const event = buffer.slice(0, cut);
      buffer = buffer.slice(cut + 2);
      for (const line of event.split('\n')) if (line.startsWith('data: ')) yield line.slice(6);
      cut = buffer.indexOf('\n\n');
    }
  }
}
