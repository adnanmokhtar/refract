<?php

namespace App\Console\Commands;

use App\Enums\InvoiceStatus;
use App\Models\Invoice;
use App\Services\InvoiceService;
use Illuminate\Console\Command;

class IssueNightlyInvoices extends Command
{
    protected $signature = 'invoices:issue-nightly';

    protected $description = 'Issue every draft invoice whose order shipped before midnight';

    public function handle(InvoiceService $invoices): int
    {
        Invoice::withoutGlobalScopes()->where('status', InvoiceStatus::Draft)->whereNotNull('order_id')->each(fn (Invoice $i) => $invoices->issue($i));

        return self::SUCCESS;
    }
}
