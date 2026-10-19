import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Courier } from './courier.entity';

/** Cash on delivery: the courier collected the order's cash and now owes it to the platform. */
@Injectable()
export class CourierCodService {
  constructor(private readonly em: EntityManager) {}

  async onDelivered(courierId: string, order: { id: string; codMinor: number }): Promise<void> {
    const courier = await this.em.findOneOrFail(Courier, courierId);
    courier.codBalanceMinor += order.codMinor;
    await this.em.flush();
    await this.em.getConnection().execute(
      `insert into courier_cod_entries (courier_id, order_id, amount_minor) values (?, ?, ?)`,
      [courierId, order.id, order.codMinor],
    );
  }
}
