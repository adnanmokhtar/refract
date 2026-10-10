import pino from 'pino';
import { LedgerStore } from './ledger.store';

// The ledger export runs inside the API process on the finance team's daily trigger.
// Its logger maps the `error` key through pino's error serializer (type, message, stack).
const ledgerLog = pino({
  name: 'ledger-export',
  serializers: { error: pino.stdSerializers.err },
});

export async function exportLedger(day: string, store: LedgerStore): Promise<void> {
  try {
    await store.exportDay(day);
    ledgerLog.info({ day }, 'ledger exported');
  } catch (err) {
    ledgerLog.error({ error: err, day }, 'ledger export failed');
    throw err;
  }
}
