export interface OutboxPort {
  /**
   * Records an event in the outbox inside the caller's transaction. The relay publishes it after commit.
   * Must be called inside `TxRunner.run`: the row commits or rolls back with the business write.
   */
  emit(type: string, payload: Record<string, unknown>, aggregateId: string): Promise<void>;
}

export const OUTBOX_PORT = Symbol('OUTBOX_PORT');
