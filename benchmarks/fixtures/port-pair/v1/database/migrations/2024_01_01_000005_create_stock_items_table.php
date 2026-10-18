<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('stock_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('account_id')->constrained();
            $table->string('sku', 40);
            $table->string('description', 200);
            $table->unsignedInteger('quantity_available')->default(0);
            $table->unsignedInteger('quantity_reserved')->default(0);
            $table->unsignedInteger('pack_size')->default(1);
            $table->unsignedSmallInteger('reorder_level')->default(10);
            $table->string('unit', 8)->default('each');
            $table->softDeletes();
            $table->timestamps();
            $table->index(['account_id', 'sku']);
        });
    }
};
