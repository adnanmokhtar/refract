/** Click-and-collect: if today's slot is full, the shopper is offered the same time tomorrow (store local time). */
export interface Slot {
  startsAt: Date;
  storeTimezone: string;
}

export function sameTimeTomorrow(slot: Slot): Slot {
  const next = new Date(slot.startsAt.getTime() + 24 * 60 * 60 * 1000);
  return { startsAt: next, storeTimezone: slot.storeTimezone };
}
