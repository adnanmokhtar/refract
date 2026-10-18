import { EntityManager, type EntityName, type EventArgs, type EventSubscriber } from '@mikro-orm/core';
import { Injectable } from '@nestjs/common';
import { ActivityService } from '../common/activity.service';
import { Wallet } from './wallet.entity';

// The V2 side of spatie's LogsActivity on V1's Wallet (logOnly balance_minor, credit_limit_minor;
// log name `wallets`): one activity_log row per audited change, whoever made it.
@Injectable()
export class WalletActivitySubscriber implements EventSubscriber<Wallet> {
  constructor(em: EntityManager, private readonly activity: ActivityService) {
    em.getEventManager().registerSubscriber(this);
  }

  getSubscribedEntities(): EntityName<Wallet>[] {
    return [Wallet];
  }

  async afterCreate(args: EventArgs<Wallet>): Promise<void> {
    this.activity.log('created', args.entity, { attributes: pick(args.entity) }, 'wallets');
  }

  async afterDelete(args: EventArgs<Wallet>): Promise<void> {
    this.activity.log('deleted', args.entity, { old: pick(args.entity) }, 'wallets');
  }
}

function pick(w: Wallet) {
  return { balance_minor: w.balanceMinor, credit_limit_minor: w.creditLimitMinor };
}
