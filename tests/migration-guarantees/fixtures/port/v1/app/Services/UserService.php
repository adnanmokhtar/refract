<?php
class UserService {
  public function create(array $data) {
    if (User::where('email', $data['email'])->exists()) { abort(409); }
    return User::create($data);
  }
}
