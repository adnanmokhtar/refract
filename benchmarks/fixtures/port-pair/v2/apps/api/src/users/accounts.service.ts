import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable, UnprocessableEntityException } from '@nestjs/common';
import type { UpdateAccountBodyT } from '@norrow/contracts';
import { Account } from './account.entity';

@Injectable()
export class AccountsService {
  constructor(private readonly em: EntityManager) {}

  async update(accountId: number, value: UpdateAccountBodyT) {
    if (Buffer.byteLength(value.company_name, 'utf8') > 60) {
      throw new UnprocessableEntityException({ message: 'The company name field must not be greater than 60 characters.', errors: { company_name: ['The company name field must not be greater than 60 characters.'] } });
    }

    const account = await this.em.findOneOrFail(Account, accountId);
    this.em.assign(account, { companyName: value.company_name, vatNumber: value.vat_number ?? null, billingEmail: value.billing_email });
    await this.em.flush();
    return { data: { id: account.id, company_name: account.companyName, vat_number: account.vatNumber ?? null, billing_email: account.billingEmail } };
  }
}
