<?php

namespace App\Observers;

use App\Models\Invoice;
use Illuminate\Support\Facades\DB;

class InvoiceObserver
{
    public function updated(Invoice $invoice): void
    {
        DB::table('invoice_audit')->insert([
            'invoice_id' => $invoice->id,
            'changes' => json_encode($invoice->getChanges()),
            'changed_by' => auth()->id(),
            'changed_at' => now(),
        ]);
    }
}
