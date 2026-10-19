<?php

namespace App\Observers;

use App\Enums\OrderStatus;
use App\Mail\OrderPlacedMail;
use App\Mail\OrderShippedMail;
use App\Models\Order;
use Illuminate\Support\Facades\Mail;

class OrderObserver
{
    public function created(Order $order): void
    {
        Mail::to($order->customer_email)->queue(new OrderPlacedMail($order));
    }

    public function updated(Order $order): void
    {
        if ($order->wasChanged('status') && $order->status === OrderStatus::Shipped) {
            Mail::to($order->customer_email)->queue(new OrderShippedMail($order));
        }
    }
}
