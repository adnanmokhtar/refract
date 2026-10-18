<?php

namespace App\Http\Controllers;

use App\Http\Requests\AdjustWalletRequest;
use App\Models\Wallet;
use App\Services\WalletService;
use App\Support\Money;
use Illuminate\Http\Request;

class WalletController extends Controller
{
    public function __construct(private WalletService $wallets)
    {
    }

    public function show(Wallet $wallet)
    {
        return response()->json(['data' => $wallet->toApi()]);
    }

    public function statement(Wallet $wallet, Request $request)
    {
        $rows = $wallet->transactions()->where('posted_at', '>=', now()->subDays(90))->orderBy('id')->get();

        return response()->json(['data' => $rows->map->toApi()]);
    }

    public function adjust(AdjustWalletRequest $request, Wallet $wallet)
    {
        $tx = $this->wallets->adjust($wallet, $request->integer('amount_minor'), $request->string('reason'), $request->user());

        return response()->json(['data' => $tx->toApi()], 201);
    }

    public function creditLimit(Request $request, Wallet $wallet)
    {
        $data = $request->validate(['credit_limit_minor' => ['required', 'integer', 'min:0', 'max:500000000']]);
        $wallet->update($data);

        return response()->json(['data' => $wallet->toApi()]);
    }

    public function installments(Request $request, Wallet $wallet)
    {
        $data = $request->validate(['total' => ['required', 'numeric', 'min:1'], 'count' => ['required', 'integer', 'between:2,12']]);

        return response()->json(['data' => Money::allocate((string) $data['total'], (int) $data['count'])]);
    }
}
