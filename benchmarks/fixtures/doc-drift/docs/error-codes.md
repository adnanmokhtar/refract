# Error codes

Auto-populated by `scripts/sync-error-codes.sh` from the platform repository; change the source there.

| Code | HTTP | Meaning |
|---|---|---|
| `TLS_HANDSHAKE` | 502 | The merchant endpoint failed the TLS handshake. |
| `RATE_LIMITED` | 429 | The API key exceeded its rate limit. |
| `WEBHOOK_REJECTED` | 422 | The endpoint URL or its event list is invalid. |
