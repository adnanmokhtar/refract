import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

@Injectable()
export class TaxRates {
  constructor(private readonly em: EntityManager) {}

  /** The standard VAT rate of a country at an instant, from the effective-dated tax_rates table. */
  async forCountry(country: string, at: Date): Promise<number> {
    const [row] = await this.em.getConnection().execute(
      `select rate_bp from tax_rates
        where country = ? and valid_from <= ? and (valid_to is null or valid_to > ?)
        order by valid_from desc limit 1`,
      [country, at, at],
    );
    return row.rate_bp / 10_000;
  }
}
