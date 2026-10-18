<?php

namespace App\Services;

use App\Models\User;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use Illuminate\Support\Facades\DB;

class WalletService
{
    public function adjust(Wallet $wallet, int $amountMinor, string $reason, User $by): WalletTransaction
    {
        return DB::transaction(function () use ($wallet, $amountMinor, $reason, $by) {
            $wallet = Wallet::lockForUpdate()->findOrFail($wallet->id);
            $wallet->balance_minor += $amountMinor;
            $wallet->save();

            return $wallet->transactions()->create([
                'amount_minor' => $amountMinor,
                'reason' => $reason,
                'posted_by' => $by->id,
                'posted_at' => now(),
            ]);
        });
    }

    public function expirePromo(Wallet $wallet): void
    {
        DB::transaction(function () use ($wallet) {
            $wallet = Wallet::withoutGlobalScopes()->lockForUpdate()->findOrFail($wallet->id);
            $expired = $wallet->promo_balance_minor;
            $wallet->balance_minor -= $expired;
            $wallet->promo_balance_minor = 0;
            $wallet->save();

            $wallet->transactions()->create(['amount_minor' => -$expired, 'reason' => 'promo-expired', 'posted_by' => null, 'posted_at' => now()]);
        });
    }
}
