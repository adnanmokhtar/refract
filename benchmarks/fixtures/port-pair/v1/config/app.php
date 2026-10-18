<?php

return [
    'name' => env('APP_NAME', 'Norrow Portal'),

    'env' => env('APP_ENV', 'production'),

    'url' => env('APP_URL', 'https://portal.norrow.example'),

    // Every naive DATETIME the portal writes is wall-clock Riyadh time.
    'timezone' => env('APP_TIMEZONE', 'Asia/Riyadh'),

    'locale' => 'ar',

    'fallback_locale' => 'en',

    'currency' => 'SAR',
];
