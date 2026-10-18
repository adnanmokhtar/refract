<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tickets', function (Blueprint $table) {
            $table->id();
            $table->foreignId('account_id')->constrained();
            $table->string('subject', 150);
            $table->text('body');
            $table->string('status', 10)->default('open');
            $table->unsignedTinyInteger('priority')->default(2);
            $table->unsignedBigInteger('assignee_id')->nullable();
            $table->unsignedBigInteger('opened_by');
            $table->unsignedBigInteger('order_id')->nullable();
            $table->dateTime('due_at')->nullable();
            $table->dateTime('closed_at')->nullable();
            $table->softDeletes();
            $table->timestamps();
        });

        Schema::create('ticket_messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ticket_id')->constrained('tickets')->cascadeOnDelete();
            $table->unsignedBigInteger('author_id');
            // 1 = portal, 2 = e-mail reply, 3 = SMS reply.
            $table->unsignedTinyInteger('channel')->default(1);
            $table->text('body');
            $table->timestamps();
        });

        Schema::create('tags', function (Blueprint $table) {
            $table->id();
            $table->string('name', 40)->unique();
            $table->boolean('is_system')->default(false);
        });

        Schema::create('tag_ticket', function (Blueprint $table) {
            $table->foreignId('tag_id')->constrained()->cascadeOnDelete();
            $table->foreignId('ticket_id')->constrained()->cascadeOnDelete();
            $table->primary(['tag_id', 'ticket_id']);
        });
    }
};
