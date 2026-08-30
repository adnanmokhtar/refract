---
name: logging
description: Cross-cutting rules for what is written to logs — content, correlation, volume and cost
kind: rule
concern: C5
---

# Logging

## Hard rule

Every log line MUST be answerable on four counts: **what is in it**, **who can read it**, **what
it costs**, and **how it joins to the rest of the request**. A log with none of these is a
liability that grows at the rate of traffic. Logs are a data store with no schema, no retention
policy and, usually, the widest read access in the company.

## Why this concern had no home

The repo already extracts *logger identity* — which library, which transport — in
`_extracted-codebase.md § 8`. Nothing reviewed **what is logged**. That is the gap the plan's own
Phase 4 list arrived at independently, and it had no home because concerns had no directory.

Distinct from **C3 Observability**, which asks *can you tell it broke*. Logging asks the narrower
question of what the lines themselves contain and cost.

## Per-surface fingerprints

| Surface | What ends up in the log | Typical finding |
|---|---|---|
| `file-upload` | filenames, paths, and sometimes content | user-supplied filenames logged unescaped — log injection; full paths reveal storage layout |
| `media-processing` | transcoder stderr, EXIF dumps | GPS coordinates from EXIF logged during processing; ffmpeg command lines carrying signed URLs |
| `multi-tenant` | the tenant anchor, or its absence | logs carry no tenant id, so an incident cannot be scoped to a tenant; or logs are pooled so one tenant's support read exposes another's |
| `notifications` | full message bodies and recipients | the entire rendered email or SMS body logged on send, including whatever PII the template merged in |
| `rate-limiting` | every rejected request | a 429 storm logs one line per rejection, so the incident that triggers the limiter also floods the log bill |
| `scheduling` | attendee lists and appointment subjects | subjects logged verbatim, carrying health or legal context in a store with wide read access |
| `search` | raw query strings | user queries logged in full — among the most sensitive text a user ever types |

## The four questions, as a checklist

| Question | Finding when unanswered |
|---|---|
| **What is in it** | PII, secrets, tokens, or user content logged verbatim |
| **Who can read it** | log store has broader access than the database it describes |
| **What it costs** | per-request debug logging left on; no sampling on high-volume paths |
| **How it joins** | no correlation id at boundaries, so a request cannot be reassembled across services |

## Per-`project_kind` rendering

| Concern shape | `server` | `browser` | `mobile` | `cli` |
|---|---|---|---|---|
| **Where it lands** | a shipped log store with wide read access | the user's console, and any error-reporting SDK | device logs readable by other tooling, plus crash reports | stdout/stderr, and whatever CI archives |
| **The classic miss** | request/response bodies logged wholesale | `console.log` of an auth response left in prod | a token in logcat; PII in a crash breadcrumb | secrets echoed by a verbose flag, captured in CI logs forever |

## Closure verbs

`redact-field` · `sample-high-volume` · `add-correlation-id` · `escape-user-input` ·
`narrow-log-access` · `drop-body-logging`
