<?php

namespace App\Http\Controllers;

use App\Http\Requests\UpdateAccountRequest;
use Illuminate\Http\Request;

class MeController extends Controller
{
    public function show(Request $request)
    {
        return response()->json(['data' => $request->user()->toApi()]);
    }

    public function updateAccount(UpdateAccountRequest $request)
    {
        $account = $request->user()->account;
        $account->update($request->validated());

        return response()->json(['data' => $account->toApi()]);
    }
}
