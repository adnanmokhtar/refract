export const retryPolicy = {
  limit: 2,
  methods: ['get', 'head'],
  statusCodes: [408, 429, 502, 503, 504],
};

export function backoffMs(attempt: number): number {
  return Math.min(1000 * 2 ** attempt, 8000);
}
