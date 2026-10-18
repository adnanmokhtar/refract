<?php

namespace App\Services;

use App\Models\StockItem;
use Illuminate\Validation\ValidationException;

class StockService
{
    public function reserve(string $sku, int $quantity): StockItem
    {
        // Always called inside the caller's DB::transaction.
        $item = StockItem::lockForUpdate()->where('sku', strtoupper(trim($sku)))->firstOrFail();

        if ($item->quantity_available - $item->quantity_reserved < $quantity) {
            throw ValidationException::withMessages(['lines' => ["Not enough stock for {$sku}."]]);
        }

        $item->increment('quantity_reserved', $quantity);

        return $item;
    }

    public function packsAvailable(StockItem $item): int
    {
        $free = $item->quantity_available - $item->quantity_reserved;
        $packs = intdiv($free, $item->pack_size);

        return max($packs, 0);
    }
}
