<?php

namespace App\Services;

use App\Models\Ticket;

class SlaService
{
    private const ESCALATION_ORDER = ['tier1', 'tier2', 'duty-manager'];

    public function summary(Ticket $ticket): array
    {
        $minutesLeft = (int) now()->diffInMinutes($ticket->due_at, false);
        $hours = intdiv($minutesLeft, 60);

        if ($minutesLeft < 0) {
            return ['id' => $ticket->id, 'state' => 'breached', 'hours' => $hours, 'escalate_to' => $this->nextTier('tier1')];
        }

        return ['id' => $ticket->id, 'state' => 'within', 'hours' => $hours, 'escalate_to' => null];
    }

    public function nextTier(string $current): ?string
    {
        $pos = array_search($current, self::ESCALATION_ORDER, true);

        if ($pos === false) {
            return self::ESCALATION_ORDER[0];
        }

        return self::ESCALATION_ORDER[$pos + 1] ?? null;
    }
}
