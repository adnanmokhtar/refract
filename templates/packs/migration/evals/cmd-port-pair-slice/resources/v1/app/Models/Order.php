<?php

namespace App\Models;

use App\Enums\OrderStatus;
use App\Models\Scopes\AccountScope;
use App\Observers\OrderObserver;
use Illuminate\Database\Eloquent\Attributes\ObservedBy;
use Illuminate\Database\Eloquent\Attributes\ScopedBy;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

#[ScopedBy([AccountScope::class])]
#[ObservedBy([OrderObserver::class])]
class Order extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = ['account_id', 'number', 'status', 'po_number', 'notes', 'currency', 'channel', 'customer_email', 'total_amount', 'shipped_at'];

    protected $attributes = [
        'status' => 'draft',
        'currency' => 'SAR',
        'channel' => 'portal',
    ];

    protected $casts = [
        'status' => OrderStatus::class,
        'total_amount' => 'decimal:2',
        'shipped_at' => 'datetime',
    ];

    public function lines(): HasMany
    {
        return $this->hasMany(OrderLine::class);
    }

    public function toApi(): array
    {
        return [
            'id' => $this->id,
            'number' => $this->number,
            'status' => $this->status->value,
            'po_number' => $this->po_number,
            'currency' => $this->currency,
            'total' => $this->total_amount,
            'line_count' => $this->line_count,
            'shipped_at' => $this->shipped_at?->toIso8601String(),
            'lines' => $this->relationLoaded('lines') ? $this->lines->map->toApi()->values() : [],
        ];
    }
}
