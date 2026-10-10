import { App } from 'aws-cdk-lib';
import { LedgerArchiveStack } from '../lib/ledger-archive-stack';

const app = new App();
new LedgerArchiveStack(app, 'LarderLedgerArchive', { env: { region: 'eu-central-1' } });
