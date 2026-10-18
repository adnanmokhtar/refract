import { backfillInvoices } from './invoices.backfill';
import { openSource } from './lib/source';
import { openTarget } from './lib/target';
import { backfillOrderLines, backfillOrders } from './orders.backfill';
import { preflight } from './preflight';
import { backfillStock } from './stock.backfill';
import { backfillTickets } from './tickets.backfill';
import { backfillUsers } from './users.backfill';
import { backfillWallets } from './wallets.backfill';
import { verifyWalletTransactions } from './wallet-transactions.backfill';

const source = await openSource();
const target = await openTarget();

await preflight(source);
await backfillUsers(source, target);
await backfillOrders(source, target);
await backfillOrderLines(source, target);
await backfillInvoices(source, target);
await backfillWallets(source, target);
await backfillStock(source, target);
await backfillTickets(source, target);
await verifyWalletTransactions(source, target, Number(process.env.LEDGER_HIGH_WATER_ID));
