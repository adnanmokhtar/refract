<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Notification;

class TicketOpenedSms extends Notification implements ShouldQueue
{
    use Queueable;

    public function __construct(public int $ticketId, public string $preview)
    {
    }

    public function via(object $notifiable): array
    {
        return ['sms'];
    }

    public function toSms(object $notifiable): string
    {
        return "Ticket #{$this->ticketId}: {$this->preview}";
    }
}
