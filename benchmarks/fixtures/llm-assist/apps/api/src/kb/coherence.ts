/**
 * Reply quality heuristics shown next to an agent's draft. Pure functions, no network.
 */
const SENTENCE_END = /(?<=[.!?])\s+/;

export function coherenceScore(reply: string, topicTerms: string[]): number {
  const sentences = reply.split(SENTENCE_END).filter(Boolean);
  if (sentences.length === 0) return 0;
  const terms = topicTerms.map((t) => t.toLowerCase());
  const onTopic = sentences.filter((s) => terms.some((t) => s.toLowerCase().includes(t)));
  return onTopic.length / sentences.length;
}

export function isIncoherent(reply: string, topicTerms: string[]): boolean {
  return coherenceScore(reply, topicTerms) < 0.4;
}
