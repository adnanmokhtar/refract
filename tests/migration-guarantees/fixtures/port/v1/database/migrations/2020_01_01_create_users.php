<?php
Schema::create('users', function ($table) {
  $table->id();
  $table->string('email')->unique();
  $table->string('name');
});
