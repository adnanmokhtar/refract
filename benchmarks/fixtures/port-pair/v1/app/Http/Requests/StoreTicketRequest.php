<?php

namespace App\Http\Requests;

use App\Enums\TicketPriority;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreTicketRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'subject' => ['required', 'string', 'max:150'],
            'body' => ['required', 'string', 'max:5000'],
            'priority' => ['sometimes', Rule::enum(TicketPriority::class)],
            'order_id' => ['nullable', 'integer', 'exists:orders,id'],
        ];
    }
}
