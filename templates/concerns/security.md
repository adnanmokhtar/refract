---
name: security
description: Cross-cutting exploitability rules for the surfaces the security pack does not reach
kind: rule
concern: C1
---

# Security

## Hard rule

Every input crossing a trust boundary MUST be validated **on the far side of that boundary**, and
every secret MUST have a custody path — where it is stored, who can read it, and how it is
rotated. This concern asks *is it exploitable*; **C8 Authorization** asks *at which layer is the
check*. Both are needed: a system can be inexploitable today and have an authorization
architecture that guarantees an IDOR next quarter.

The `security` pack covers request-shaped surfaces well. The matrix found only **5 surfaces**
empty — this file is deliberately narrow, and that narrowness is the finding worth recording:
security review in this repo was already broad.

## Per-surface fingerprints

| Surface | The trust boundary | Typical finding |
|---|---|---|
| `data-pipeline` | the source system and the transform code | pipelines run with the widest credential in the system and read every tenant by design; a compromised transform exfiltrates through a legitimate sink |
| `event-sourced` | the event payload, which is permanent | secrets or PII written into events — immutable by design, so the leak cannot be deleted, only re-encrypted around |
| `ledger` | the money-mutating path | balance derived client-side or from a mutable column; integer-money violated so rounding becomes an exploit surface |
| `real-time` | the persistent connection, authenticated once | authorization checked at connect and never re-checked, so a session outlives the permission that opened it; no per-message scope |
| `scheduling` | the invite and the public booking link | booking links guessable, exposing availability and attendee identity; ICS feeds served without a token |

## Per-`project_kind` rendering

| Concern shape | `server` | `browser` | `mobile` | `cli` |
|---|---|---|---|---|
| **Trust boundary** | every request, every queue message | everything from the page is untrusted server-side | same, plus deep links and IPC | argv, env, stdin, and the filesystem |
| **Secret custody** | secret store, rotated, never in code | there are no secrets in a browser — only public values | keychain/keystore, never in the bundle | file mode `0600`, never in shell history |
| **The classic miss** | validating on the client and trusting it on the server | a token in `localStorage` reachable by any script | an API key shipped in the binary | a secret passed as a command-line argument, visible in `ps` |

## Closure verbs

`validate-server-side` · `rotate-and-scope-credential` · `recheck-on-message` ·
`tokenize-public-link` · `keep-secret-out-of-immutable-store` · `narrow-pipeline-credential`
