<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'po_number' => ['sometimes', 'nullable', 'string', 'max:30', 'regex:/^[A-Z0-9-]+$/'],
            'notes' => ['sometimes', 'nullable', 'string', 'max:500'],
        ];
    }
}
