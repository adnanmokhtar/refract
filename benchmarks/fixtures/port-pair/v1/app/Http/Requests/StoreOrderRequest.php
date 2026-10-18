<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'po_number' => ['nullable', 'string', 'max:30', 'regex:/^[A-Z0-9-]+$/'],
            'notes' => ['nullable', 'string', 'max:500'],
            'currency' => ['sometimes', 'string', 'in:SAR,AED'],
            'lines' => ['required', 'array', 'min:1', 'max:200'],
            'lines.*.sku' => ['required', 'string', 'max:40'],
            'lines.*.quantity' => ['required', 'integer', 'min:1', 'max:100000'],
            'lines.*.unit_price' => ['required', 'numeric', 'min:0'],
            'lines.*.discount_rate' => ['nullable', 'numeric', 'between:0,0.5'],
        ];
    }
}
