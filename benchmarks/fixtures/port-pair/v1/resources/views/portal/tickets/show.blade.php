@extends('layouts.portal')

@section('content')
    <h1>#{{ $ticket->id }} — {{ $ticket->subject }}</h1>

    @foreach ($ticket->messages as $message)
        <article class="message">{{ $message->body }}</article>
    @endforeach

    @if (in_array($ticket->status->value, ['solved', 'closed'], true))
        <form method="POST" action="/api/tickets/{{ $ticket->id }}/reopen">
            @csrf
            <button type="submit">{{ __('tickets.reopen') }}</button>
        </form>
    @endif
@endsection
