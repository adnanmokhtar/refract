<?php

namespace Tests\Feature;

use App\Models\Invoice;
use App\Services\InvoiceService;
use App\Services\PricingService;
use Tests\TestCase;

class InvoiceTotalsTest extends TestCase
{
    public function test_tax_is_rounded_per_line_then_summed(): void
    {
        $invoice = Invoice::factory()->withLines([['10.03', 1], ['10.03', 1], ['10.03', 1], ['10.03', 1], ['47.18', 1]])->make(['tax_rate' => '0.15']);

        $totals = app(InvoiceService::class)->totals($invoice);

        $this->assertSame('87.30', number_format($totals['subtotal'], 2, '.', ''));
        $this->assertSame('13.08', number_format($totals['tax'], 2, '.', ''));
    }

    public function test_credit_lines_round_half_away_from_zero(): void
    {
        $pricing = app(PricingService::class);

        $this->assertSame('-1.13', $pricing->creditFor('2.25', 0.5));
        $this->assertSame('-0.03', $pricing->creditFor('0.05', 0.5));
    }
}
