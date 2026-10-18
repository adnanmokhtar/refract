<?php

namespace App\Models\Scopes;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Scope;

class AccountScope implements Scope
{
    public function apply(Builder $builder, Model $model): void
    {
        if ($user = auth()->user()) {
            $builder->where($model->qualifyColumn('account_id'), $user->account_id);
        }
    }
}
