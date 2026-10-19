import type { NestFastifyApplication } from '@nestjs/platform-fastify';

// AC-003: a refund takes back the points the order awarded. deductPoints() is what the refund
// path is meant to call; the balance helper reads the ledger for the assertion.
export async function pointsBalance(app: NestFastifyApplication, customerId: string): Promise<number> {
  const res = await app.inject({ method: 'GET', url: `/api/loyalty/customers/${customerId}/balance` });
  return (res.json() as { balance: number }).balance;
}
