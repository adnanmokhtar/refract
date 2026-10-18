<?php

namespace App\Services;

use App\Models\StockItem;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;

class CsvImportService
{
    public function import(string $path, int $accountId): array
    {
        $created = 0;
        $rejected = [];

        foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $n => $line) {
            [$sku, $description] = explode(',', $line, 2);
            $row = ['sku' => strtoupper(trim($sku)), 'description' => trim($description ?? '')];

            $v = Validator::make($row, [
                'sku' => ['required', 'max:40', Rule::unique('stock_items', 'sku')->where('account_id', $accountId)->whereNull('deleted_at')],
                'description' => ['required', 'max:200'],
            ]);

            if ($v->fails()) {
                $rejected[] = ['line' => $n + 1, 'errors' => $v->errors()->all()];
                continue;
            }

            StockItem::create($row + ['account_id' => $accountId, 'quantity_available' => 0, 'pack_size' => 1]);
            $created++;
        }

        return ['created' => $created, 'rejected' => $rejected];
    }
}
