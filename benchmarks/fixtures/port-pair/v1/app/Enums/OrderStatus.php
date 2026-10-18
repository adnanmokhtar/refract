<?php

namespace App\Enums;

enum OrderStatus: string
{
    case Draft = 'draft';
    case Placed = 'placed';
    case Packed = 'packed';
    case Shipped = 'shipped';
    case Cancelled = 'cancelled';
    case Refunded = 'refunded';
}
