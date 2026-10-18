<?php

namespace App\Services;

use App\Enums\InvoiceStatus;
use App\Jobs\ProcessInvoiceIssued;
use App\Models\Invoice;
use Illuminate\Support\Facades\DB;

class InvoiceService
{
    public function totals(Invoice $invoice): array
    {
        $subtotal = 0.0;
        $tax = 0.0;

        foreach ($invoice->lines as $line) {
            $net = round((float) $line->unit_price * $line->quantity, 2);
            $tax += round($net * (float) $invoice->tax_rate, 2);
            $subtotal += $net;
        }

        return ['subtotal' => round($subtotal, 2), 'tax' => round($tax, 2), 'total' => round($subtotal + $tax, 2)];
    }

    public function issue(Invoice $invoice): Invoice
    {
        return DB::transaction(function () use ($invoice) {
            $totals = $this->totals($invoice);
            $sequence = DB::table('invoice_sequences')->where('year', now()->year)->lockForUpdate()->increment('last_value');
            $invoice->number = sprintf('INV-%d-%06d', now()->year, $sequence);
            $invoice->subtotal_amount = $totals['subtotal'];
            $invoice->tax_amount = $totals['tax'];
            $invoice->total_amount = $totals['total'];
            $invoice->status = InvoiceStatus::Issued;
            $invoice->issued_at = now();
            $invoice->save();

            ProcessInvoiceIssued::dispatch($invoice)->afterCommit();

            return $invoice;
        });
    }
}
