---
name: ssrf-scan
description: Static taint-trace for SSRF egress sinks — user-controlled URL reaching an outbound fetch with no allow-list, unblocked internal/metadata ranges, hostname validated but not the resolved IP (DNS rebinding), followed redirects, dangerous URL schemes, and reachable IMDSv1. Run on any endpoint that fetches a user-supplied URL, unfurls a link, imports from a URL, or registers a webhook. Not a dependency or secret scan — `@security-auditor` A01 dispatches here for depth.
kind: skill
pack: security
---

# Skill: ssrf-scan

## Premise

Server-Side Request Forgery is a top-tier vulnerability (folded into OWASP **A01:2025**) and the one the auditor's checklist can only surface as a single bullet. It happens whenever the server makes an outbound request to a **URL or host derived from user input** without an allow-list — the attacker turns your server into a proxy to reach cloud metadata (`169.254.169.254`), internal services, and localhost admin ports. This skill is the dedicated static detector for the egress sinks.

**Every finding cites the sink at `<file:line>` + the user-controlled source + the fix.** "Might be SSRF-able" without the cited fetch call and the tainted input is not a finding. Static taint-trace: a user-controlled value reaching an outbound-request API.

## Adapt to the codebase

Detect the HTTP-client + URL-validation primitive in use and phrase fixes in it:

| Stack | Outbound sink to grep | Allow-list / validation primitive |
|---|---|---|
| **Node** | `fetch`, `axios`, `got`, `http.request`, `undici` | a URL allow-list + `dns.lookup` on the resolved IP; `undici` `connect` hook |
| **Python** | `requests`, `httpx`, `urllib`, `aiohttp` | validate + resolve; `requests` no-redirect + custom adapter |
| **Go** | `http.Get/Do`, `net/http` | `http.Transport.DialContext` that rejects private IPs |
| **Java** | `HttpClient`, `RestTemplate`, `URL.openConnection` | URL validator + `no-redirect` |
| **Ruby/PHP** | `Net::HTTP`, `open-uri`, `Guzzle`, `file_get_contents` | allow-list; disable `allow_url_fopen` for user input |

The common SSRF sinks to prioritize: webhook/callback registration, **fetch-image/avatar-by-URL**, link-preview / OpenGraph unfurl, PDF / HTML-to-image render, import-from-URL, and any proxy endpoint.

## Scans for

### 1. User-controlled URL reaches an outbound fetch with no allow-list

```
BAD:   const r = await fetch(req.body.url)                 // attacker → http://169.254.169.254/…
GOOD:  const u = new URL(req.body.url);
       if (!ALLOWED_HOSTS.has(u.hostname) || u.protocol !== 'https:') reject(400)
       // then fetch by the RESOLVED, re-checked IP
```
Grep the outbound sinks (§ table) for a URL/host argument traceable to `req.*` / request input with no preceding allow-list check.

### 2. No block of internal / metadata ranges

Flag a validated fetch that checks the hostname *string* but not the ranges: `169.254.169.254` (AWS/Azure/GCP metadata), `metadata.google.internal`, `127.0.0.0/8`, `::1`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `0.0.0.0`. Block these on the **resolved** IP.

### 3. Hostname validated but not the resolved IP (DNS rebinding)

```
BAD:   if (allowed(u.hostname)) fetch(u)                    // DNS rebinds evil.com → 169.254.169.254
GOOD:  const ip = await dns.lookup(u.hostname); assertPublic(ip); fetch(u, { lookup: () => ip })
```
Flag validation on the hostname alone with no resolve-then-pin — the attacker's DNS can rebind between the check and the fetch (TOCTOU).

### 4. Redirects followed to a denied host

Flag an HTTP client that follows redirects by default with no per-hop re-validation (a `200`→`302`→`http://169.254…`). Disable auto-redirect or re-check each hop.

### 5. Dangerous URL schemes allowed

Flag a fetch that accepts `file://`, `gopher://`, `dict://`, `ftp://`, `data:` from user input — restrict to `https:` (and `http:` only if required).

### 6. Cloud-metadata reachable / IMDSv1

Flag no egress restriction to the metadata IP, and (infra-adjacent) IMDSv1 still enabled on the instance — recommend IMDSv2 (hop-limit 1, token-required) via the infrastructure pack.

## Upload egress note

The *inbound* upload surface (magic-byte type validation, size cap, path traversal, uuid keys, storage outside webroot) is owned by the backend `file-upload` pattern + the `security-principles` file-upload MUST — dispatch there. The **security-specific** upload risks to also flag: an SVG accepted as an image (SVG carries script → stored XSS), a polyglot file (valid image + valid HTML/JS), and an image processed by a native parser with a known CVE (ImageMagick/`libvips`) — treat user images as untrusted input to the parser.

## Output

```
ssrf-scan — <route set>

Findings: 2

1. src/services/preview.service.ts:31                  [report-with-fix]
   fetch(req.body.url) — user URL, no allow-list. Reachable: 169.254.169.254 (AWS metadata).
   Fix: URL allow-list + resolve-and-pin the IP + reject private/metadata ranges + https-only.

2. src/avatar/import.ts:12                             [report-flagged]
   axios.get(url, { maxRedirects: 5 }) validates hostname but follows redirects.
   Fix: maxRedirects: 0 (or re-validate each hop against the resolved IP).
```

## False positives / gotchas

- **A hardcoded/internal URL is not SSRF** — flag only user-*controlled* URL/host inputs.
- **An allow-list of first-party hosts is the fix, not a finding** — don't re-flag a validated fetch.
- **Deny-lists are weak** — blocking `169.254.169.254` misses `[::ffff:169.254.169.254]`, decimal/octal IP encodings, and rebinding; prefer an allow-list + resolved-IP check.
- **Egress network policy is defense-in-depth**, not a substitute — the infra pack's network policy that blocks pod→metadata is the belt to this code-level suspenders.

## When to run

- On any endpoint that fetches a user-supplied URL, imports from a URL, renders/proxies remote content, or registers a webhook/callback.
- Before launch on a public API; when `@security-auditor` A01 flags an SSRF sink for deep confirmation.

## Halt conditions

- Halt on any finding without the cited sink `<file:line>` + the user-controlled source + the fix.
- Do not propose a deny-list as the primary control — require an allow-list + resolved-IP check.
- Do not flag a hardcoded/internal URL or an already-allow-listed fetch.

## Related

- `@security-auditor` — A01 (SSRF) surface pass dispatches here for depth.
- `backend/ai-patterns/file-upload.md` — the inbound upload contract; this skill covers egress + the security-specific upload risks.
- `rules/security-principles.md` — the SSRF + file-upload MUSTs.
- `infrastructure` pack — egress network policy + IMDSv2 (defense-in-depth).
