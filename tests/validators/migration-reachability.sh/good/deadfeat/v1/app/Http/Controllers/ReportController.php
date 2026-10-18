<?php
class ReportController {
    public function legacyExport() { return response()->streamDownload(fn () => null); }
}
