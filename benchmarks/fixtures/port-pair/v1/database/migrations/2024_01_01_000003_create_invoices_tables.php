<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('invoices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('account_id')->constrained();
            $table->foreignId('order_id')->nullable()->constrained();
            $table->string('number', 20)->nullable();
            $table->string('status', 10)->default('draft');
            $table->decimal('tax_rate', 6, 4)->default(0.15);
            $table->decimal('subtotal_amount', 12, 2)->default(0);
            $table->decimal('tax_amount', 12, 2)->default(0);
            $table->decimal('total_amount', 12, 2)->default(0);
            $table->string('billing_email', 120);
            $table->dateTime('issued_at')->nullable();
            $table->timestamps();
            $table->unique(['account_id', 'number']);
        });

        Schema::create('invoice_lines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('invoice_id')->constrained()->cascadeOnDelete();
            $table->string('sku', 40);
            $table->integer('quantity');
            $table->decimal('unit_price', 12, 2);
            $table->decimal('net_amount', 12, 2);
            // 1 = standard rate, 2 = zero-rated export, 3 = exempt.
            $table->unsignedTinyInteger('tax_category')->default(1);
        });

        Schema::create('invoice_audit', function (Blueprint $table) {
            $table->id();
            $table->foreignId('invoice_id');
            $table->json('changes');
            $table->unsignedBigInteger('changed_by')->nullable();
            $table->dateTime('changed_at');
        });

        Schema::create('invoice_sequences', function (Blueprint $table) {
            $table->unsignedSmallInteger('year')->primary();
            $table->unsignedInteger('last_value')->default(0);
        });
    }
};
