<?php

use App\Http\Controllers\Admin\UserController as AdminUserController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\InvoiceController;
use App\Http\Controllers\MeController;
use App\Http\Controllers\OrderController;
use App\Http\Controllers\ReportController;
use App\Http\Controllers\StockController;
use App\Http\Controllers\TicketController;
use App\Http\Controllers\WalletController;
use Illuminate\Support\Facades\Route;

Route::post('/auth/token', [AuthController::class, 'token']);

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', [MeController::class, 'show']);
    Route::patch('/account', [MeController::class, 'updateAccount']);

    Route::controller(OrderController::class)->prefix('orders')->group(function () {
        Route::get('/', 'index')->middleware('can:orders.view');
        Route::post('/', 'store')->middleware('can:orders.create');
        Route::get('/export', 'export')->middleware('can:orders.view');
        Route::get('/{order}', 'show')->middleware('can:view,order');
        Route::patch('/{order}', 'update')->middleware('can:update,order');
        Route::post('/{order}/cancel', 'cancel')->middleware('can:update,order');
        Route::post('/{order}/duplicate', 'duplicate')->middleware('can:orders.create');
    });

    Route::controller(InvoiceController::class)->prefix('invoices')->group(function () {
        Route::get('/', 'index')->middleware('can:invoices.view');
        Route::get('/{invoice}', 'show');
        Route::get('/{invoice}/pdf', 'pdf');
        Route::post('/{invoice}/issue', 'issue')->middleware('can:invoices.issue');
    });

    Route::controller(WalletController::class)->prefix('wallets')->group(function () {
        Route::get('/{wallet}', 'show')->middleware('permission:wallets.view');
        Route::get('/{wallet}/statement', 'statement')->middleware('permission:wallets.view');
        Route::post('/{wallet}/adjust', 'adjust')->middleware('permission:wallets.adjust');
        Route::post('/{wallet}/credit-limit', 'creditLimit')->middleware('permission:wallets.adjust');
        Route::post('/{wallet}/installments', 'installments')->middleware('permission:wallets.view');
    });

    Route::controller(StockController::class)->prefix('stock')->group(function () {
        Route::get('/', 'index');
        Route::get('/low-stock', 'lowStock');
        Route::post('/import', 'import')->middleware('permission:stock.import');
        Route::get('/{sku}', 'show');
        Route::post('/{sku}/reserve', 'reserve')->middleware('permission:stock.reserve');
    });

    Route::apiResource('tickets', TicketController::class)->only(['index', 'store', 'show']);
    Route::patch('/tickets/{ticket}', [TicketController::class, 'update'])->middleware('role:agent|admin');
    Route::post('/tickets/{ticket}/reopen', [TicketController::class, 'reopen']);
    Route::post('/tickets/next', [TicketController::class, 'next'])->middleware('role:agent|admin');

    Route::get('/reports/sales', [ReportController::class, 'sales'])->middleware('can:reports.view');
    Route::get('/reports/sla', [ReportController::class, 'sla'])->middleware('can:reports.view');
    Route::get('/reports/legacy-aging', [ReportController::class, 'legacyAging'])->middleware('can:reports.view');

    Route::middleware('role:admin')->prefix('admin')->group(function () {
        Route::get('/users', [AdminUserController::class, 'index']);
        Route::get('/users/{user}', [AdminUserController::class, 'show']);
        Route::put('/users/{user}/roles', [AdminUserController::class, 'syncRoles']);
    });
});

Route::fallback(fn () => response()->json(['message' => 'Not Found.'], 404));
