import { api } from '../api/client';

export type PickWrite = {
  id: string;
  pickListId: string;
  lineId: string;
  quantity: number;
  substitutedWith?: string;
};

const MAX_ATTEMPTS = 8;

// Picks recorded while the store Wi-Fi drops out. The line turns green on screen as soon as the pick is queued here.
const pendingWrites: PickWrite[] = [];
const attempts = new Map<string, number>();
export const failed: PickWrite[] = [];

export function enqueue(write: PickWrite): void {
  pendingWrites.push(write);
}

export function clear(): void {
  pendingWrites.length = 0;
  attempts.clear();
}

/** Sends queued picks in order. The server adds each pick's quantity to the line's picked total. */
export async function flush(): Promise<void> {
  while (pendingWrites.length > 0) {
    const write = pendingWrites[0];
    try {
      await api.post(`/pick-lists/${write.pickListId}/picks`, {
        lineId: write.lineId,
        quantity: write.quantity,
        substitutedWith: write.substitutedWith,
      });
      pendingWrites.shift();
    } catch {
      const n = (attempts.get(write.id) ?? 0) + 1;
      attempts.set(write.id, n);
      if (n >= MAX_ATTEMPTS) failed.push(pendingWrites.shift() as PickWrite);
      return;
    }
  }
}
