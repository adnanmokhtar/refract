<?php

use App\Exceptions\OrderNotEditableException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->statefulApi();

        // TrimStrings and ConvertEmptyStringsToNull stay in the global stack (framework default);
        // only the password fields are exempt from trimming.
        $middleware->trimStrings(except: ['password', 'password_confirmation', 'current_password']);

        $middleware->alias([
            'role' => \Spatie\Permission\Middleware\RoleMiddleware::class,
            'permission' => \Spatie\Permission\Middleware\PermissionMiddleware::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        $exceptions->render(function (OrderNotEditableException $e) {
            return response()->json(['message' => $e->getMessage(), 'code' => 'order_not_editable'], 409);
        });

        $exceptions->shouldRenderJsonWhen(fn ($request) => $request->is('api/*'));
    })->create();
