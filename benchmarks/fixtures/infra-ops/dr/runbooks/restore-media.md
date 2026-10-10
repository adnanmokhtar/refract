# Restore — media library

1. `velero restore create --from-backup <media-daily-YYYYMMDD…> --include-namespaces larder-media`
2. Wait for the restore to report `Completed`, then restart `media-processor`.

## Drill log

- 2026-09-18: restored media-library from media-daily-20260917 into larder-media over the live claim; three images spot-checked in the shop.
