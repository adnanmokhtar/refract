export interface DigestQueue {
  pending: string[];
  flush(lines: string[]): void;
}

// Agents get one digest of new returns every five minutes instead of an email per return.
export function startDigest(queue: DigestQueue, everyMs = 5 * 60_000): () => void {
  const timer = setInterval(() => {
    if (queue.pending.length === 0) return;
    queue.flush(queue.pending.splice(0));
  }, everyMs);
  return () => clearInterval(timer);
}
