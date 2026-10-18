<?php

use App\Jobs\ReleaseStaleReservations;
use App\Jobs\SendWeeklyReport;
use Illuminate\Support\Facades\Schedule;

Schedule::command('invoices:issue-nightly')->dailyAt('01:30')->timezone('Asia/Riyadh')->onOneServer();

Schedule::command('wallets:expire-credits')->dailyAt('00:15')->timezone('Asia/Riyadh')->onOneServer();

Schedule::job(new ReleaseStaleReservations)->everyFiveMinutes()->withoutOverlapping();

Schedule::command('stock:export-feed')->dailyAt('05:00')->timezone('Asia/Riyadh');

Schedule::job(new SendWeeklyReport)->weeklyOn(0, '07:00')->timezone('Asia/Riyadh');
