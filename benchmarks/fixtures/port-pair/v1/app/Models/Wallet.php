<?php

namespace App\Models;

use App\Models\Scopes\AccountScope;
use Illuminate\Database\Eloquent\Attributes\ScopedBy;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Spatie\Activitylog\LogOptions;
use Spatie\Activitylog\Traits\LogsActivity;

#[ScopedBy([AccountScope::class])]
class Wallet extends Model
{
    use LogsActivity;

    protected $fillable = ['account_id', 'balance_minor', 'credit_limit_minor', 'currency'];

    public function getActivitylogOptions(): LogOptions
    {
        return LogOptions::defaults()
            ->logOnly(['balance_minor', 'credit_limit_minor'])
            ->logOnlyDirty()
            ->useLogName('wallets');
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(WalletTransaction::class);
    }

    public function toApi(): array
    {
        return [
            'id' => $this->id,
            'balance_minor' => $this->balance_minor,
            'credit_limit_minor' => $this->credit_limit_minor,
            'currency' => $this->currency,
        ];
    }
}
