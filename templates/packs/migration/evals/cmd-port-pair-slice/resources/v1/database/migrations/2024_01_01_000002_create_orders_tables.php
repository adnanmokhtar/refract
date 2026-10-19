<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('account_id')->constrained();
            $table->string('number', 20)->unique();
            $table->string('status', 20)->default('draft');
            $table->string('po_number', 30)->nullable();
            $table->text('notes')->nullable();
            $table->char('currency', 3)->default('SAR');
            $table->string('channel', 20)->default('portal');
            $table->string('customer_email');
            $table->decimal('total_amount', 12, 2)->default(0);
            $table->unsignedInteger('line_count')->default(0);
            $table->dateTime('shipped_at')->nullable();
            $table->softDeletes();
            $table->timestamps();
        });

        Schema::create('order_lines', function (Blueprint $table) {
            $table->id();
            // Legacy: no foreign key; lines of purged orders were never cleaned up.
            $table->unsignedBigInteger('order_id')->index();
            $table->string('sku', 40);
            $table->integer('quantity');
            $table->decimal('unit_price', 12, 2);
            $table->decimal('discount_rate', 5, 4)->nullable();
            $table->decimal('net_amount', 12, 2);
            $table->timestamps();
        });

        DB::unprepared(<<<'SQL'
            CREATE TRIGGER order_lines_after_insert AFTER INSERT ON order_lines
            FOR EACH ROW UPDATE orders SET line_count = line_count + 1 WHERE id = NEW.order_id
        SQL);
    }
};
