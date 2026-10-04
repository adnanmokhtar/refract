import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { EntityManager, IsolationLevel } from '@mikro-orm/postgresql';
import { Order } from '../orders/order.entity';
import { PickupBooking } from './pickup-booking.entity';
import { PickupSlot } from './pickup-slot.entity';

// Click-and-collect: a buyer picks a 30-minute window at checkout. Popular stores sell out
// the Saturday-morning windows within minutes of opening them.
@Injectable()
export class PickupSlotsService {
  constructor(private readonly em: EntityManager) {}

  async available(storeId: string, from: Date, to: Date) {
    const slots = await this.em.find(PickupSlot, { store: storeId, startsAt: { $gte: from, $lt: to } }, { orderBy: { startsAt: 'asc' } });
    const counts: { slot_id: string; n: string }[] = await this.em.execute(
      'select slot_id, count(*) as n from pickup_booking where slot_id = any(?) group by slot_id',
      [slots.map((s) => s.id)],
    );
    const taken = new Map(counts.map((c) => [c.slot_id, Number(c.n)]));
    return slots.map((s) => ({ id: s.id, startsAt: s.startsAt, left: s.capacity - (taken.get(s.id) ?? 0) }));
  }

  // POST /orders/:orderId/pickup — book a window. Capacity must never be exceeded, so the
  // count and the insert run under SERIALIZABLE.
  async book(orderId: string, slotId: string): Promise<PickupBooking> {
    return this.em.transactional(
      async (em) => {
        const slot = await em.findOne(PickupSlot, { id: slotId });
        if (!slot) throw new NotFoundException('no such pickup window');
        const booked = await em.count(PickupBooking, { slot });
        if (booked >= slot.capacity) throw new ConflictException('that window is full');
        const booking = new PickupBooking(slot, em.getReference(Order, orderId));
        em.persist(booking);
        return booking;
      },
      { isolationLevel: IsolationLevel.SERIALIZABLE },
    );
  }
}
