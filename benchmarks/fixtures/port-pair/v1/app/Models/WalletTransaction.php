<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

// Append-only: rows are inserted, never updated or deleted.
class WalletTransaction extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = ['wallet_id', 'amount_minor', 'reason', 'posted_by', 'posted_at'];

    protected $casts = ['posted_at' => 'datetime'];

    public function toApi(): array
    {
        return [
            'id' => $this->id,
            'amount_minor' => $this->amount_minor,
            'reason' => $this->reason,
            'posted_at' => $this->posted_at->toIso8601String(),
        ];
    }
}
