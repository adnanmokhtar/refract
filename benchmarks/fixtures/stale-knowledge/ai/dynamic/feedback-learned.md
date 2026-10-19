# Feedback learned

Corrections the user gave more than once. `Repeated: 2` or more promotes an entry into `.claude/rules/`.

## Format per entry

```
### YYYY-MM-DD — <short rule>
Status: WATCHING | RULE_CANDIDATE | PROMOTED | REJECTED
Repeated: <count>
Source: <session, PR or commit>
```

## Entries

### 2026-07-25 — short answers in reviews
Status: WATCHING
Repeated: 1
Source: user, 2026-07-25
Review replies stay at two or three lines; link the rule instead of restating it.
It applies to review threads, not to design discussions.

### 2026-08-02 — name the tenant in log lines
Status: WATCHING
Repeated: 1
Source: PR #33 review
A log line without the tenant id cannot be traced back to a customer report.

### 2026-08-14 — return 404, not 403, for another tenant's order
Status: WATCHING
Repeated: 1
Source: PR #41 review
Answering 403 tells the caller the order exists in another tenant; answer 404.

### 2026-09-01 — keep controllers thin
Status: WATCHING
Repeated: 3
Source: PR #52, PR #58 and PR #63 reviews
Business rules go into services and use cases; a controller parses, calls once and maps.

### 2026-09-03 — return 404, not 403, for another tenant's order
Status: WATCHING
Repeated: 1
Source: PR #57 review
The refund endpoint answered 403 for another tenant's refund; same correction as before.

### 2026-09-12 — DTO validation on new endpoints
Status: WATCHING
Repeated: 1
Source: PR #60 review
Prefer `class-validator` DTOs on new endpoints; they document the shape in one place.

### 2026-09-20 — paginate admin lists
Status: WATCHING
Repeated: 1
Admin lists grew past a thousand rows; page them like the public lists.
