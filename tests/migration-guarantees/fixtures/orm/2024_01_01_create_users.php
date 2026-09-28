$table->string('email')->unique();
$request->validate(['email' => 'required|email|unique:users,email']);
