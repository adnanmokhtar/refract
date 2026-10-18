<?php

namespace App\Enums;

enum TicketStatus: string
{
    case Open = 'open';
    case Pending = 'pending';
    case Solved = 'solved';
    case Closed = 'closed';
}
