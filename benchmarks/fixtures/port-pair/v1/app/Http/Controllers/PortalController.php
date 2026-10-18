<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Models\Ticket;
use Illuminate\Http\Request;

class PortalController extends Controller
{
    public function orders(Request $request)
    {
        $orders = Order::query()
            ->when($request->input('status'), fn ($q, $s) => $q->whereIn('status', (array) $s))
            ->latest()
            ->paginate(25)
            ->withQueryString();

        return view('portal.orders', ['orders' => $orders, 'status' => (array) $request->input('status', [])]);
    }

    public function createOrder()
    {
        return view('portal.orders.create');
    }

    public function wallet(Request $request)
    {
        return view('portal.wallet', ['wallet' => $request->user()->account->wallet]);
    }

    public function statements(Request $request)
    {
        return view('portal.statements', ['wallet' => $request->user()->account->wallet]);
    }

    public function ticket(Ticket $ticket)
    {
        return view('portal.tickets.show', ['ticket' => $ticket->load('messages')]);
    }
}
