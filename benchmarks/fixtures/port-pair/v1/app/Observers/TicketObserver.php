<?php

namespace App\Observers;

use App\Models\Ticket;
use App\Notifications\TicketOpenedSms;
use App\Models\User;
use Illuminate\Support\Facades\Notification;

class TicketObserver
{
    public function created(Ticket $ticket): void
    {
        $preview = mb_substr($ticket->subject, 0, 50);

        Notification::send(User::role('agent')->where('account_id', $ticket->account_id)->get(), new TicketOpenedSms($ticket->id, $preview));
    }
}
