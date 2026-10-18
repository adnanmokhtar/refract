<?php

namespace App\Jobs;

use App\Mail\WeeklySalesReport;
use App\Models\Account;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Support\Facades\Mail;

class SendWeeklyReport implements ShouldQueue
{
    use Dispatchable, Queueable;

    public function handle(): void
    {
        Account::query()->each(fn (Account $a) => Mail::to($a->billing_email)->send(new WeeklySalesReport($a)));
    }
}
