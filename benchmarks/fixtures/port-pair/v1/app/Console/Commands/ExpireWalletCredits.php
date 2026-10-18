<?php

namespace App\Console\Commands;

use App\Models\Wallet;
use App\Services\WalletService;
use Illuminate\Console\Command;

class ExpireWalletCredits extends Command
{
    protected $signature = 'wallets:expire-credits';

    protected $description = 'Expire promotional credit older than 180 days';

    public function handle(WalletService $wallets): int
    {
        Wallet::withoutGlobalScopes()->where('promo_balance_minor', '>', 0)->where('promo_granted_at', '<', now()->subDays(180))->each(
            fn (Wallet $w) => $wallets->expirePromo($w)
        );

        return self::SUCCESS;
    }
}
