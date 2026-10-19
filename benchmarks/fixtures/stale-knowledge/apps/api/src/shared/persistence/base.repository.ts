import { EntityManager } from '@mikro-orm/postgresql';

export abstract class BaseRepository<T extends object> {
  constructor(protected readonly em: EntityManager) {}

  async save(entity: T): Promise<T> {
    this.em.persist(entity);
    return entity;
  }
}
