<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class AdjustWalletRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'amount_minor' => ['required', 'integer', 'not_in:0', 'between:-50000000,50000000'],
            'reason' => ['required', 'string', 'max:120'],
        ];
    }
}
