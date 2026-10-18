<?php

return [
    'driver' => env('SESSION_DRIVER', 'redis'),

    'lifetime' => 120,

    'cookie' => env('SESSION_COOKIE', 'norrow_session'),

    'path' => '/',

    // Shared by portal.norrow.example and app.norrow.example during the cutover window.
    'domain' => env('SESSION_DOMAIN', '.norrow.example'),

    'secure' => true,

    'http_only' => true,

    // The card provider redirects back with a top-level GET; strict would drop the session.
    'same_site' => 'lax',
];
