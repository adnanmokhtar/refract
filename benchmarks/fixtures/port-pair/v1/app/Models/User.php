<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;
use Spatie\Permission\Traits\HasRoles;

class User extends Authenticatable
{
    use HasApiTokens, HasRoles;

    protected $fillable = ['name', 'email', 'password', 'account_id', 'locale'];

    protected $hidden = ['password', 'remember_token'];

    protected function email(): Attribute
    {
        return Attribute::make(set: fn (string $value) => strtolower($value));
    }

    public function account(): BelongsTo
    {
        return $this->belongsTo(Account::class);
    }

    public function toApi(): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'roles' => $this->roles->pluck('name')->values(),
        ];
    }
}
