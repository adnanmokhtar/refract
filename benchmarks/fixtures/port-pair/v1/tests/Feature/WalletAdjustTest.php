<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Wallet;
use Tests\TestCase;

class WalletAdjustTest extends TestCase
{
    public function test_adjustment_posts_a_transaction_and_logs_activity(): void
    {
        $user = User::factory()->withPermission('wallets.adjust')->create();
        $wallet = Wallet::factory()->for($user->account)->create(['balance_minor' => 10_000]);

        $this->actingAs($user)->postJson("/api/wallets/{$wallet->id}/adjust", ['amount_minor' => -2_500, 'reason' => 'damaged goods'])->assertCreated();

        $this->assertSame(7_500, $wallet->fresh()->balance_minor);
        $this->assertDatabaseHas('activity_log', ['log_name' => 'wallets', 'subject_id' => $wallet->id]);
    }
}
