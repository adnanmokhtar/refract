<?php

namespace App\Http\Controllers;

use App\Models\Invoice;
use App\Services\InvoiceService;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Request;

class InvoiceController extends Controller
{
    public function __construct(private InvoiceService $invoices)
    {
    }

    public function index(Request $request)
    {
        $invoices = Invoice::query()->latest('issued_at')->paginate(min((int) $request->input('per_page', 25), 100));

        return response()->json(['data' => $invoices->getCollection()->map->toApi()]);
    }

    public function show(Invoice $invoice)
    {
        $this->authorize('view', $invoice);

        return response()->json(['data' => $invoice->load('lines')->toApi()]);
    }

    public function pdf(Invoice $invoice)
    {
        $this->authorize('view', $invoice);

        return Pdf::loadView('invoices.pdf', ['invoice' => $invoice->load('lines')])->download($invoice->number.'.pdf');
    }

    public function issue(Invoice $invoice)
    {
        $this->authorize('issue', $invoice);

        return response()->json(['data' => $this->invoices->issue($invoice)->toApi()]);
    }
}
