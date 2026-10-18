@extends('layouts.portal')

@section('content')
    <h1>{{ __('orders.new') }}</h1>

    <form method="POST" action="/api/orders" onsubmit="this.querySelector('button[type=submit]').disabled = true">
        @csrf
        @include('portal.orders.lines-editor')
        <button type="submit">{{ __('orders.place') }}</button>
    </form>
@endsection
