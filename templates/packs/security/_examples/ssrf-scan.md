---
name: ssrf-scan
description: Static taint-trace for URL-shaped sinks — user-controlled URL reaching an outbound fetch with no allow-list, unblocked internal/metadata ranges, hostname validated but not the resolved IP (DNS rebinding), followed redirects, dangerous URL schemes, reachable IMDSv1, and user-controlled redirect targets (open redirector). Run on any endpoint that fetches a user-supplied URL, unfurls a link, imports from a URL, registers a webhook, or bounces the browser to a URL from a query parameter. Not a dependency or secret scan — `/security-audit` dispatches here when its A01 surface fires.
kind: example
pack: security
---

# Skill: ssrf-scan

SSRF (OWASP A01:2025) = the server makes an outbound request to a user-controlled URL/host with no allow-list → the attacker reaches cloud metadata (169.254.169.254), internal services, localhost. Static taint-trace over URL-shaped sinks: the egress ones, plus the one redirect sink that shares their taint source (§7). Detect the HTTP-client + validation primitive per stack (fetch/axios/requests/httpx/http.Get/Guzzle).

## Premise

**Every finding cites the sink at `<file:line>` + the user-controlled source + the fix.** "Might be SSRF-able" without the cited fetch call and the tainted input is not a finding. Static taint-trace: a user-controlled value reaching an outbound-request API.

## Pre-flight greps

The greps produce candidates; a finding is a hit **plus** a read of the enclosing function.

```bash
# 1. every outbound sink (the universe)
rg -n --pcre2 '\b(fetch|axios(\.\w+)?|got|undici|http\.request|requests\.(get|post|put|request)|httpx\.|urlopen|http\.Get|open-uri|file_get_contents|curl_exec)\s*\(' -g '!**/node_modules/**' -g '!**/vendor/**'
# 2. sinks whose argument is request-derived (§1 finding set)
rg -n --pcre2 '\b(fetch|axios(\.\w+)?|got|http\.request|requests\.(get|post)|httpx\.|urlopen|http\.Get)\s*\([^)]*\b(req|request|params|query|body|input|payload|dto)\b' -g '!**/node_modules/**'
# 3. redirect policy — its ABSENCE on a default-following client is the finding (§4)
rg -n 'maxRedirects|allow_redirects|follow_redirects|CheckRedirect'
# 4. hostname-only validation vs actual resolution — the set difference is §3
rg -n 'hostname|\.host\b|allowedHosts|ALLOWED_HOSTS'
rg -n 'dns\.lookup|dns\.resolve|getaddrinfo|net\.LookupIP'
# 5. redirect sinks fed from input (§7)
rg -n --pcre2 '\b(res\.redirect|redirect|sendRedirect|Location)\b[^;\n]*\b(req|request|query|params|body|next|returnUrl|redirect_uri|continue|target|url)\b'
```

## Scans for

1. User URL → outbound fetch with no allow-list.
2. No block of internal/metadata ranges (169.254.169.254, 127./10./172.16-31./192.168., ::1, metadata.google.internal) — block on the RESOLVED IP.
3. Hostname validated but not the resolved IP (DNS rebinding / TOCTOU) → resolve-and-pin.
4. Redirects followed to a denied host → maxRedirects 0 / re-validate each hop.
5. Dangerous schemes (file://, gopher://, dict://, data:) → https-only.
6. Cloud metadata reachable / IMDSv1 → IMDSv2 (infra).
7. **User-controlled redirect target (open redirector)** — `?next=`/`?returnUrl=`/`?redirect_uri=` reflected into `Location` or a redirect helper. Same taint, browser-side sink. OAuth 2.1 § 2.3.1: *"Clients MUST NOT expose URLs that forward the user's browser to arbitrary URIs obtained from a query parameter ('open redirector')… Open redirectors can enable exfiltration of authorization codes and access tokens"* (<https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1-13>). Fix order: relative-path-only → allow-list of return origins. Never a prefix check. **Boundary:** `@auth-reviewer` covers the auth surface (login-return, post-logout, OAuth callback) where this chains to code exfiltration; grep 5 here sweeps *every* redirect sink, including the ones no auth review reaches — hand auth-path hits back to that agent rather than re-deriving the chain.

## Upload note

Inbound upload (magic-byte/size/path/uuid) owned by backend file-upload + the rule MUST. Security-specific: SVG-as-image (stored XSS), polyglots, native image-parser CVE (ImageMagick/libvips).

## Output

```
ssrf-scan — <route set>

Findings: 3

1. src/services/preview.service.ts:31                  [report-with-fix]
   fetch(req.body.url) — user URL, no allow-list. Reachable: 169.254.169.254 (AWS metadata).
   Fix: URL allow-list + resolve-and-pin the IP + reject private/metadata ranges + https-only.

2. src/avatar/import.ts:12                             [report-flagged]
   axios.get(url, { maxRedirects: 5 }) validates hostname but follows redirects.
   Fix: maxRedirects: 0 (or re-validate each hop against the resolved IP).

3. src/auth/callback.controller.ts:44                  [report-with-fix]
   res.redirect(req.query.returnUrl) — open redirector on the OAuth callback path.
   Fix: relative-path-only, else an allow-list of return origins. Never a prefix check.
```

## Gotchas

Hardcoded/internal URL ≠ SSRF (only user-controlled). An allow-list is the fix, not a finding. Deny-lists are weak (encodings/rebinding) — allow-list + resolved-IP. **A prefix check is not an origin check** (`startsWith('https://our.app')` accepts `https://our.app.evil.example`). Egress NetworkPolicy is defense-in-depth.

## Halt conditions

No finding without the cited sink + user source + fix; no deny-list as the primary control; don't flag hardcoded/allow-listed fetches; **never report a bare grep hit** — every row needs the read of the enclosing function that establishes the taint path.

## Related

`/security-audit` (dispatches here when its A01/outbound-fetch signal fires) · `@security-auditor` (its A01 SSRF row is the detector; this is the executor) · `@auth-reviewer` (redirect-URI registration + the auth-surface open redirector; §7 sweeps every redirect sink app-wide) · backend `file-upload` (inbound) · `security-principles` · infrastructure (egress policy + IMDSv2).
