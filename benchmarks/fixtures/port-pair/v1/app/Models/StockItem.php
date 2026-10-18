<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class StockItem extends Model
{
    use SoftDeletes;

    protected $fillable = ['account_id', 'sku', 'description', 'quantity_available', 'quantity_reserved', 'pack_size', 'reorder_level', 'unit'];

    protected static function booted(): void
    {
        static::addGlobalScope('account', function (Builder $builder) {
            if ($user = auth()->user()) {
                $builder->where('stock_items.account_id', $user->account_id);
            }
        });
    }

    public function toApi(): array
    {
        return [
            'sku' => $this->sku,
            'description' => $this->description,
            'quantity_available' => $this->quantity_available,
            'quantity_reserved' => $this->quantity_reserved,
            'reorder_level' => $this->reorder_level,
            'unit' => $this->unit,
        ];
    }
}
