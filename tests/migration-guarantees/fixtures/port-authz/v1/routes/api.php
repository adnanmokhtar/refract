<?php
use Illuminate\Support\Facades\Route;
Route::get('/orders', [OrderController::class, 'index']);
Route::delete('/orders/{order}', [OrderController::class, 'destroy'])->middleware('can:orders.delete');
