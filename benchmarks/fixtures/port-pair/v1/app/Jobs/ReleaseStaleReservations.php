<?php

namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Support\Facades\DB;

class ReleaseStaleReservations implements ShouldQueue
{
    use Dispatchable, Queueable;

    public function handle(): void
    {
        // Draft orders abandoned for 30 minutes give their reserved stock back.
        DB::statement(<<<'SQL'
            UPDATE stock_items si
            JOIN (
                SELECT ol.sku, o.account_id, SUM(ol.quantity) AS qty
                FROM order_lines ol JOIN orders o ON o.id = ol.order_id
                WHERE o.status = 'draft' AND o.updated_at < NOW() - INTERVAL 30 MINUTE AND o.deleted_at IS NULL
                GROUP BY ol.sku, o.account_id
            ) stale ON stale.sku = si.sku AND stale.account_id = si.account_id
            SET si.quantity_reserved = GREATEST(si.quantity_reserved - stale.qty, 0)
        SQL);
    }
}
