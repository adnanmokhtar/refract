<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;

class InvoiceIssuedMail extends Mailable
{
    use Queueable;

    public function __construct(public mixed $subject_model)
    {
    }
}
