<?php

namespace App\Services;

use App\Models\Order;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class OrderPlacementService
{
    public function __construct(private StockService $stock, private PricingService $pricing)
    {
    }

    public function place(array $data, User $user): Order
    {
        return DB::transaction(function () use ($data, $user) {
            $order = Order::create([
                'account_id' => $user->account_id,
                'number' => 'SO-'.str_pad((string) (Order::withTrashed()->max('id') + 1), 7, '0', STR_PAD_LEFT),
                'status' => 'placed',
                'po_number' => $data['po_number'] ?? null,
                'notes' => $data['notes'] ?? null,
                'customer_email' => $user->email,
            ] + (isset($data['currency']) ? ['currency' => $data['currency']] : []));

            $total = 0.0;
            foreach ($data['lines'] as $line) {
                $this->stock->reserve($line['sku'], (int) $line['quantity']);
                $net = $this->pricing->lineNet((string) $line['unit_price'], (int) $line['quantity'], $line['discount_rate'] ?? null);
                $order->lines()->create($line + ['net_amount' => $net]);
                $total += (float) $net;
            }

            $order->update(['total_amount' => round($total, 2)]);

            return $order->fresh('lines');
        });
    }

    public function duplicate(Order $order, User $user): Order
    {
        return $this->place([
            'po_number' => null,
            'notes' => $order->notes,
            'currency' => $order->currency,
            'lines' => $order->lines->map(fn ($l) => ['sku' => $l->sku, 'quantity' => $l->quantity, 'unit_price' => $l->unit_price, 'discount_rate' => $l->discount_rate])->all(),
        ], $user);
    }
}
