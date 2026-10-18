<?php

namespace App\Models;

use App\Enums\InvoiceStatus;
use App\Models\Scopes\AccountScope;
use App\Observers\InvoiceObserver;
use Illuminate\Database\Eloquent\Attributes\ObservedBy;
use Illuminate\Database\Eloquent\Attributes\ScopedBy;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[ScopedBy([AccountScope::class])]
#[ObservedBy([InvoiceObserver::class])]
class Invoice extends Model
{
    protected $fillable = ['account_id', 'order_id', 'number', 'status', 'tax_rate', 'subtotal_amount', 'tax_amount', 'total_amount', 'billing_email', 'issued_at'];

    protected $casts = [
        'status' => InvoiceStatus::class,
        'tax_rate' => 'decimal:4',
        'subtotal_amount' => 'decimal:2',
        'tax_amount' => 'decimal:2',
        'total_amount' => 'decimal:2',
        'issued_at' => 'datetime',
    ];

    public function lines(): HasMany
    {
        return $this->hasMany(InvoiceLine::class);
    }

    public function toApi(): array
    {
        $lines = $this->lines->map->toApi()->all();

        return [
            'id' => $this->id,
            'number' => $this->number,
            'status' => $this->status->value,
            'subtotal' => $this->subtotal_amount,
            'tax' => $this->tax_amount,
            'total' => $this->total_amount,
            'issued_at' => $this->issued_at?->toIso8601String(),
            'lines' => array_filter($lines, fn (array $l) => $l['quantity'] != 0),
        ];
    }
}
