import type Redis from 'ioredis';
import { CreditWalletService } from './credit-wallet.service';

const CLAIM_TTL_SECONDS = 7 * 24 * 3600;

/**
 * Charges a document import once, after its validated result is stored. A redelivered job finds
 * the claim and returns without charging again.
 */
export async function settleImportCharge(
  redis: Redis,
  wallet: CreditWalletService,
  job: { id: string; accountId: string },
  credits: number,
): Promise<boolean> {
  const claimed = await redis.set(`import-charge:${job.id}`, '1', 'EX', CLAIM_TTL_SECONDS, 'NX');
  if (claimed !== 'OK') return false;
  await wallet.debit(job.accountId, credits, `import:${job.id}`);
  return true;
}
