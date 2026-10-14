import { Injectable, UnprocessableEntityException } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';
import { Principal } from '../common/current-user.decorator';

@Injectable()
export class CartsService {
  constructor(private readonly em: EntityManager) {}

  async validate(user: Principal, id: string): Promise<{ ok: boolean; problems: string[] }> {
    const [cart] = await this.em.getConnection().execute('select locked_at from carts where id = ? and tenant_id = ?', [id, user.tenantId]);
    if (cart?.locked_at) {
      throw new UnprocessableEntityException({ code: 'CART_LOCKED', lockedAt: cart.locked_at });
    }
    return { ok: true, problems: [] };
  }
}
