<?php

namespace App\Http\Controllers;

use App\Models\Invoice;
use App\Models\Ticket;
use App\Services\SlaService;
use Carbon\Carbon;
use Illuminate\Http\Request;

class ReportController extends Controller
{
    public function sales(Request $request)
    {
        $from = Carbon::parse($request->input('from'))->startOfDay();
        $to = Carbon::parse($request->input('to'))->endOfDay();

        $rows = Invoice::query()
            ->whereBetween('issued_at', [$from, $to])
            ->selectRaw('DATE(issued_at) as day, SUM(total_amount) as total')
            ->groupBy('day')
            ->orderBy('day')
            ->get();

        $avg = round((float) $rows->avg('total'), 2);

        return response()->json(['data' => $rows, 'meta' => ['average_daily_total' => number_format($avg, 2, '.', '')]]);
    }

    public function sla(SlaService $sla)
    {
        return response()->json(['data' => Ticket::query()->where('status', 'open')->get()->map(fn (Ticket $t) => $sla->summary($t))]);
    }

    public function legacyAging()
    {
        return response()->json(['data' => Invoice::query()->where('status', 'issued')->where('issued_at', '<', now()->subDays(90))->get()]);
    }
}
