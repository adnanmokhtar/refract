<?php

namespace Tests\Feature;

use App\Models\User;
use Tests\TestCase;

class StoreOrderValidationTest extends TestCase
{
    public function test_every_invalid_field_is_reported_at_once(): void
    {
        $user = User::factory()->clerk()->create();

        $this->actingAs($user)
            ->postJson('/api/orders', ['po_number' => 'po 12', 'lines' => [['sku' => '', 'quantity' => 0]]])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['po_number', 'lines.0.sku', 'lines.0.quantity', 'lines.0.unit_price']);
    }
}
