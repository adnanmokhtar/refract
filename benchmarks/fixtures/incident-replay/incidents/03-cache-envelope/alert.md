# AccountsSessionErrors — page

Fired:    2026-08-21T10:06:00Z (accounts 5xx ratio above 14.4 x budget)
Service:  accounts (Django 5, 8 pods), Redis 7 session cache
Symptom:  500 on authenticated pages, users logged out; started during the 2.3.0 rollout, CONTINUED after rollback to 2.2.4
Scope:    users with a session touched after 10:02
Recovered: 10:58 after `redis-cli --scan --pattern 'sess:*' | xargs redis-cli del`
