import { MikroORM } from '@mikro-orm/postgresql';
import { CreditWalletService } from '../billing/credit-wallet.service';
import { startExtractionWorker } from './extraction.worker';

async function main() {
  const orm = await MikroORM.init();
  startExtractionWorker(orm, new CreditWalletService(orm.em.fork()));
}

void main();
