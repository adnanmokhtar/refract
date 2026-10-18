<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Account extends Model
{
    protected $fillable = ['company_name', 'vat_number', 'billing_email'];

    public function wallet(): HasOne
    {
        return $this->hasOne(Wallet::class);
    }

    public function toApi(): array
    {
        return [
            'id' => $this->id,
            'company_name' => $this->company_name,
            'vat_number' => $this->vat_number,
            'billing_email' => $this->billing_email,
        ];
    }
}
