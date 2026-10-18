<?php

use App\Http\Controllers\ExportDownloadController;
use App\Http\Controllers\PortalController;
use Illuminate\Support\Facades\Route;

Route::middleware(['web', 'auth'])->group(function () {
    Route::view('/', 'portal.dashboard')->name('portal.home');
    Route::get('/orders', [PortalController::class, 'orders'])->name('portal.orders');
    Route::get('/orders/new', [PortalController::class, 'createOrder'])->name('portal.orders.create');
    Route::get('/wallet', [PortalController::class, 'wallet'])->name('portal.wallet');
    Route::get('/wallet/statements', [PortalController::class, 'statements'])->name('portal.wallet.statements');
    Route::get('/tickets/{ticket}', [PortalController::class, 'ticket'])->name('portal.tickets.show');
});

// Signed, expiring links e-mailed by the nightly exports; the signature is the authorisation.
Route::get('/exports/{file}', [ExportDownloadController::class, 'show'])
    ->middleware(['auth', 'signed'])
    ->name('exports.download');
