<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InvoiceLine extends Model
{
    protected $fillable = ['invoice_id', 'sku', 'quantity', 'unit_price', 'net_amount'];

    protected $casts = [
        'unit_price' => 'decimal:2',
        'net_amount' => 'decimal:2',
    ];

    public function toApi(): array
    {
        return ['sku' => $this->sku, 'quantity' => $this->quantity, 'unit_price' => $this->unit_price, 'net' => $this->net_amount];
    }
}
