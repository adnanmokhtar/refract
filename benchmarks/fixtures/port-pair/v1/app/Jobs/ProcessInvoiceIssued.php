<?php

namespace App\Jobs;

use App\Mail\InvoiceIssuedMail;
use App\Models\Invoice;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Mail;

class ProcessInvoiceIssued implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(public Invoice $invoice)
    {
    }

    public function handle(): void
    {
        Mail::to($this->invoice->billing_email)->send(new InvoiceIssuedMail($this->invoice));
    }
}
