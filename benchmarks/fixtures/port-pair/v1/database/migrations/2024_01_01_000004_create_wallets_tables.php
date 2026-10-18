<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('wallets', function (Blueprint $table) {
            $table->id();
            $table->foreignId('account_id')->unique()->constrained();
            $table->bigInteger('balance_minor')->default(0);
            $table->bigInteger('promo_balance_minor')->default(0);
            $table->dateTime('promo_granted_at')->nullable();
            $table->bigInteger('credit_limit_minor')->default(0);
            $table->char('currency', 3)->default('SAR');
            $table->timestamps();
        });

        Schema::create('wallet_transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('wallet_id')->constrained();
            $table->bigInteger('amount_minor');
            $table->string('reason', 120);
            $table->unsignedBigInteger('posted_by')->nullable();
            $table->dateTime('posted_at');
            $table->timestamp('created_at')->nullable();
        });
    }
};
