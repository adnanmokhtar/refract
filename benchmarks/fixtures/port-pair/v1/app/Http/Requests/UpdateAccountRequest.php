<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateAccountRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('account.update');
    }

    public function rules(): array
    {
        return [
            'company_name' => ['required', 'string', 'max:60'],
            'vat_number' => ['nullable', 'string', 'size:15'],
            'billing_email' => ['required', 'email', 'max:120'],
        ];
    }
}
