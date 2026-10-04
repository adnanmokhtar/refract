import { Injectable } from '@nestjs/common';
import { EntityManager, QueryOrder } from '@mikro-orm/postgresql';
import { Country } from './country.entity';

const DAY_MS = 86_400_000;

@Injectable()
export class CountriesService {
  private cache?: { at: number; rows: Country[] };

  constructor(private readonly em: EntityManager) {}

  // GET /countries — the country picker on every address form. ISO 3166 list, 250 rows,
  // edited about once a year.
  async all(): Promise<Country[]> {
    if (this.cache && Date.now() - this.cache.at < DAY_MS) return this.cache.rows;
    const rows = await this.em.find(Country, {}, { orderBy: { name: QueryOrder.ASC } });
    this.cache = { at: Date.now(), rows };
    return rows;
  }
}
