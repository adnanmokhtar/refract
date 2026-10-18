<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('accounts', function (Blueprint $table) {
            $table->id();
            $table->string('company_name', 60);
            $table->string('vat_number', 15)->nullable();
            $table->string('billing_email', 120);
            $table->timestamps();
        });

        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->foreignId('account_id')->constrained();
            $table->string('name');
            // Not unique: two accounts may each invite the same accountant.
            $table->string('email')->index();
            $table->string('password');
            $table->string('locale', 5)->default('ar');
            $table->rememberToken();
            $table->timestamps();
        });
    }
};
