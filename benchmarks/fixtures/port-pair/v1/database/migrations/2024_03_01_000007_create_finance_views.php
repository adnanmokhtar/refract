<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // Read by the finance team's BI workbook through the reports_ro login (not the app).
        DB::statement(<<<'SQL'
            CREATE VIEW finance_invoice_totals AS
            SELECT i.account_id, DATE(i.issued_at) AS day, SUM(i.subtotal_amount) AS subtotal, SUM(i.tax_amount) AS tax, SUM(i.total_amount) AS total
            FROM invoices i WHERE i.status IN ('issued', 'paid') GROUP BY i.account_id, DATE(i.issued_at)
        SQL);

        DB::statement(<<<'SQL'
            CREATE VIEW finance_wallet_movements AS
            SELECT w.account_id, DATE(t.posted_at) AS day, SUM(t.amount_minor) AS net_minor
            FROM wallet_transactions t JOIN wallets w ON w.id = t.wallet_id GROUP BY w.account_id, DATE(t.posted_at)
        SQL);

        DB::statement("GRANT SELECT ON norrow.finance_invoice_totals TO 'reports_ro'@'%'");
        DB::statement("GRANT SELECT ON norrow.finance_wallet_movements TO 'reports_ro'@'%'");
    }
};
