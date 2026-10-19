<?php

namespace App\Http\Controllers;

use App\Enums\OrderStatus;
use App\Exceptions\OrderNotEditableException;
use App\Http\Requests\StoreOrderRequest;
use App\Http\Requests\UpdateOrderRequest;
use App\Models\Order;
use App\Services\OrderPlacementService;
use Illuminate\Http\Request;

class OrderController extends Controller
{
    public function __construct(private OrderPlacementService $placement)
    {
    }

    public function index(Request $request)
    {
        $perPage = min((int) $request->input('per_page', 25), 100);
        $statuses = (array) $request->input('status', []);

        $orders = Order::query()
            ->with('lines')
            ->when($statuses, fn ($q) => $q->whereIn('status', $statuses))
            ->paginate($perPage);

        return response()->json([
            'data' => $orders->getCollection()->map->toApi(),
            'meta' => ['page' => $orders->currentPage(), 'per_page' => $orders->perPage(), 'total' => $orders->total()],
        ]);
    }

    public function store(StoreOrderRequest $request)
    {
        $order = $this->placement->place($request->validated(), $request->user());

        return response()->json(['data' => $order->toApi()], 201);
    }

    public function export(Request $request)
    {
        return response()->streamDownload(function () {
            $out = fopen('php://output', 'w');
            fputcsv($out, ['number', 'status', 'currency', 'total']);
            Order::query()->orderBy('id')->each(fn (Order $o) => fputcsv($out, [$o->number, $o->status->value, $o->currency, $o->total_amount]));
            fclose($out);
        }, 'orders.csv');
    }

    public function show(Order $order)
    {
        return response()->json(['data' => $order->load('lines')->toApi()]);
    }

    public function update(UpdateOrderRequest $request, Order $order)
    {
        if ($order->status !== OrderStatus::Draft) {
            throw new OrderNotEditableException('Order is not editable');
        }

        $order->fill($request->validated())->save();

        return response()->json(['data' => $order->toApi()]);
    }

    public function cancel(Order $order)
    {
        $order->update(['status' => OrderStatus::Cancelled]);

        return response()->json(['data' => $order->toApi()]);
    }

    public function duplicate(Order $order)
    {
        $this->authorize('view', $order);

        $copy = $this->placement->duplicate($order, auth()->user());

        return response()->json(['data' => $copy->toApi()], 201);
    }
}
