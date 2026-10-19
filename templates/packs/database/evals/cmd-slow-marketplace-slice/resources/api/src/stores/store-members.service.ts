import { BadRequestException, ConflictException, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { StoreMember, StoreRole } from './store-member.entity';

// Team management on the store dashboard. Invariant from the product spec: a store always
// has at least one owner (owners manage payouts and are the legal contact).
@Injectable()
export class StoreMembersService {
  constructor(private readonly em: EntityManager) {}

  async list(storeId: string) {
    return this.em.find(StoreMember, { store: storeId }, { populate: ['user'], orderBy: { role: 'asc' } });
  }

  // PATCH /stores/:storeId/members/:memberId — change someone's role.
  async changeRole(storeId: string, memberId: string, role: StoreRole): Promise<StoreMember> {
    return this.em.transactional(async (em) => {
      const member = await em.findOneOrFail(StoreMember, { id: memberId, store: storeId });
      if (member.role === 'owner' && role !== 'owner') {
        const owners = await em.count(StoreMember, { store: storeId, role: 'owner' });
        if (owners <= 1) {
          throw new ConflictException('A store needs at least one owner. Promote someone else first.');
        }
      }
      member.role = role;
      return member;
    });
  }

  // DELETE /stores/:storeId/members/:memberId
  async remove(storeId: string, memberId: string): Promise<void> {
    await this.em.transactional(async (em) => {
      const member = await em.findOneOrFail(StoreMember, { id: memberId, store: storeId });
      if (member.role === 'owner') throw new BadRequestException('Demote an owner before removing them.');
      em.remove(member);
    });
  }
}
