import { EntityManager, QueryOrder } from '@mikro-orm/postgresql';
import { Ticket } from './ticket.entity';

// "Next ticket" for an agent: the highest-priority open ticket nobody owns.
export async function nextUnassigned(em: EntityManager): Promise<Ticket | null> {
  return em.findOne(
    Ticket,
    { status: 'open', assigneeId: null },
    {
      orderBy: { priority: QueryOrder.DESC },
    },
  );
}
