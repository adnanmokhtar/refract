<?php

namespace App\Enums;

// Stored as unsignedTinyInteger and sent on the wire as the integer.
enum TicketPriority: int
{
    case Low = 1;
    case Normal = 2;
    case High = 3;
    case Urgent = 4;
}
