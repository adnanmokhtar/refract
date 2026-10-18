<?php

namespace App\Policies;

use App\Models\Invoice;
use App\Models\User;

class InvoicePolicy
{
    public function view(User $user, Invoice $invoice): bool
    {
        return $user->account_id === $invoice->account_id && $user->can('invoices.view');
    }

    public function issue(User $user, Invoice $invoice): bool
    {
        return $user->account_id === $invoice->account_id && $user->can('invoices.issue');
    }
}
