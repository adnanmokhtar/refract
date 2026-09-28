<?php
Schema::create('users', function ($t) { $t->id(); $t->string('email')->unique(); });
