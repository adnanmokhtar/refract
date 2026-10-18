<?php

namespace App\Policies;

use App\Models\Order;
use App\Models\User;

class OrderPolicy
{
    public function view(User $user, Order $order): bool
    {
        return $user->account_id === $order->account_id && $user->can('orders.view');
    }

    public function update(User $user, Order $order): bool
    {
        return $user->account_id === $order->account_id && $user->can('orders.update');
    }
}
