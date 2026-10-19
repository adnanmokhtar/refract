export class ListOrdersQuery {
  /** Opaque cursor from the previous response's `nextCursor`. */
  cursor?: string;
  /** Page size, 1 to 100. */
  limit?: number;
}
