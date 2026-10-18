<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\Storage;

class ExportDownloadController extends Controller
{
    public function show(string $file)
    {
        abort_unless(Storage::disk('exports')->exists($file), 404);

        return Storage::disk('exports')->download($file);
    }
}
