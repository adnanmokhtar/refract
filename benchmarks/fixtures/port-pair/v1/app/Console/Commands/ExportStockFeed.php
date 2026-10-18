<?php

namespace App\Console\Commands;

use App\Models\StockItem;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

class ExportStockFeed extends Command
{
    protected $signature = 'stock:export-feed';

    protected $description = 'Daily stock feed for the 3PL warehouse partner (SFTP pickup at 06:00)';

    public function handle(): int
    {
        $out = fopen('php://temp', 'w+');
        fputcsv($out, ['sku', 'qty_available', 'updated_at']);

        StockItem::withoutGlobalScopes()->orderBy('sku')->each(function (StockItem $item) use ($out) {
            fputcsv($out, [$item->sku, $item->quantity_available - $item->quantity_reserved, $item->updated_at->format('Y-m-d H:i:s')]);
        });

        rewind($out);
        Storage::disk('partner_sftp')->put('stock-'.now()->format('Ymd').'.csv', stream_get_contents($out));

        return self::SUCCESS;
    }
}
