<nav class="portal-nav" aria-label="{{ __('nav.main') }}">
    <ul>
        <li><a href="{{ route('portal.home') }}">{{ __('nav.dashboard') }}</a></li>
        <li><a href="{{ route('portal.orders') }}">{{ __('nav.orders') }}</a></li>
        <li><a href="{{ route('portal.wallet') }}">{{ __('nav.wallet') }}</a></li>
        <li><a href="{{ route('portal.wallet.statements') }}">{{ __('nav.statements') }}</a></li>
        @can('reports.view')
            <li><a href="/reports">{{ __('nav.reports') }}</a></li>
        @endcan
    </ul>
</nav>
