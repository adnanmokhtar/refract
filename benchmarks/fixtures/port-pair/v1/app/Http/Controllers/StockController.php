<?php

namespace App\Http\Controllers;

use App\Models\StockItem;
use App\Services\CsvImportService;
use App\Services\StockService;
use Illuminate\Http\Request;

class StockController extends Controller
{
    public function __construct(private StockService $stock, private CsvImportService $importer)
    {
    }

    public function index(Request $request)
    {
        return response()->json(['data' => StockItem::query()->orderBy('sku')->paginate(50)->getCollection()->map->toApi()]);
    }

    public function lowStock()
    {
        return response()->json(['data' => StockItem::query()->whereColumn('quantity_available', '<=', 'reorder_level')->orderBy('sku')->get()->map->toApi()]);
    }

    public function import(Request $request)
    {
        $result = $this->importer->import($request->file('file')->getRealPath(), $request->user()->account_id);

        return response()->json(['data' => $result], 202);
    }

    public function show(string $sku)
    {
        $item = StockItem::query()->where('sku', strtoupper(trim($sku)))->firstOrFail();

        return response()->json(['data' => $item->toApi() + ['packs_available' => $this->stock->packsAvailable($item)]]);
    }

    public function reserve(Request $request, string $sku)
    {
        $data = $request->validate(['quantity' => ['required', 'integer', 'min:1']]);

        return response()->json(['data' => $this->stock->reserve($sku, $data['quantity'])->toApi()]);
    }
}
