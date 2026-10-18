<?php

namespace App\Http\Controllers;

use App\Enums\TicketPriority;
use App\Enums\TicketStatus;
use App\Http\Requests\StoreTicketRequest;
use App\Models\Ticket;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class TicketController extends Controller
{
    public function index(Request $request)
    {
        $tickets = Ticket::query()
            ->when($request->filled('q'), fn ($q) => $q->where('subject', 'like', '%'.$request->input('q').'%'))
            ->orderByDesc('id')
            ->paginate(min((int) $request->input('per_page', 25), 100));

        return response()->json(['data' => $tickets->getCollection()->map->toApi()]);
    }

    public function store(StoreTicketRequest $request)
    {
        $ticket = Ticket::create($request->validated() + ['opened_by' => $request->user()->id]);

        return response()->json(['data' => $ticket->toApi()], 201);
    }

    public function show(Ticket $ticket)
    {
        return response()->json(['data' => $ticket->load('tags', 'messages')->toApi()]);
    }

    public function update(Request $request, Ticket $ticket)
    {
        $ticket->update($request->validate([
            'status' => ['sometimes', Rule::enum(TicketStatus::class)],
            'priority' => ['sometimes', Rule::enum(TicketPriority::class)],
            'assignee_id' => ['sometimes', 'nullable', 'integer'],
        ]));

        return response()->json(['data' => $ticket->toApi()]);
    }

    public function reopen(Ticket $ticket)
    {
        $ticket->update(['status' => TicketStatus::Open, 'closed_at' => null]);

        return response()->json(['data' => $ticket->toApi()]);
    }

    public function next(Request $request)
    {
        $ticket = Ticket::query()
            ->where('status', TicketStatus::Open)
            ->whereNull('assignee_id')
            ->orderByDesc('priority')
            ->first();

        $ticket?->update(['assignee_id' => $request->user()->id]);

        return response()->json(['data' => $ticket?->toApi()]);
    }
}
