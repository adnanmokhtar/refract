import { Migration } from '@mikro-orm/migrations';

// Legacy mimics for the finance BI workbook, which reads views through the reports_ro login
// (V1 database/migrations/2024_03_01_000007_create_finance_views.php).
export class Migration20261001000000_reporting_views extends Migration {
  async up(): Promise<void> {
    this.addSql(`create view finance_wallet_movements as
      select w.account_id, (t.posted_at at time zone 'Asia/Riyadh')::date as day, sum(t.amount_minor) as net_minor
      from wallet_transactions t join wallets w on w.id = t.wallet_id group by 1, 2;`);

    this.addSql('grant select on finance_wallet_movements to reports_ro;');
  }
}
