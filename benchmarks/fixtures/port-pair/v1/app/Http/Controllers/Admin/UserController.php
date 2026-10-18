<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;

class UserController extends Controller
{
    public function index()
    {
        return response()->json(['data' => User::query()->with('roles')->orderBy('name')->get()->map->toApi()]);
    }

    public function show(User $user)
    {
        return response()->json(['data' => $user->load('roles')->toApi()]);
    }

    public function syncRoles(Request $request, User $user)
    {
        $data = $request->validate(['roles' => ['required', 'array'], 'roles.*' => ['string', 'in:admin,manager,agent,clerk']]);
        $user->syncRoles($data['roles']);

        return response()->json(['data' => $user->load('roles')->toApi()]);
    }
}
