import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { User } from '../users/user.entity';

@Injectable()
export class StaffService {
  constructor(private readonly em: EntityManager) {}

  // GET /stores/:storeId/staff/options — the "assign to" dropdown on orders, returns and
  // support tickets (opened many times per minute by busy stores; big stores have ~200 staff).
  async assigneeOptions(storeId: string): Promise<{ id: string; name: string }[]> {
    const users = await this.em.find(User, { memberships: { store: storeId } });
    return users
      .map((u) => ({ id: u.id, name: u.displayName }))
      .sort((a, b) => a.name.localeCompare(b.name));
  }
}
