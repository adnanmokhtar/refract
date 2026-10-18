@extends('layouts.portal')

@section('content')
    <h1>{{ __('orders.title') }}</h1>

    {{-- Filters live in the query string, so Back and a shared link both keep them. --}}
    <form method="GET" action="{{ route('portal.orders') }}" class="filters">
        @foreach (['placed', 'packed', 'shipped', 'cancelled'] as $s)
            <label>
                <input type="checkbox" name="status[]" value="{{ $s }}" @checked(in_array($s, $status, true))>
                {{ __('orders.status.'.$s) }}
            </label>
        @endforeach
        <button type="submit">{{ __('orders.filter') }}</button>
    </form>

    @forelse ($orders as $order)
        @include('portal.orders.row', ['order' => $order])
    @empty
        <p class="empty">{{ trans_choice('orders.items', 0) }}</p>
    @endforelse

    {{ $orders->links() }}
@endsection
