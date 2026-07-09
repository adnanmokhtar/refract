---
name: ssrf-scan
kind: example
pack: security
---

# Skill: ssrf-scan

SSRF (OWASP A01:2025) = server makes an outbound request to a user-controlled URL/host with no allow-list → attacker reaches cloud metadata (169.254.169.254), internal services, localhost. Static taint-trace of egress sinks. Every finding cites the sink <file:line> + the user-controlled source + fix. Detect the HTTP-client + validation primitive per stack (fetch/axios/requests/httpx/http.Get/Guzzle).

## Scans for

1. User URL → outbound fetch with no allow-list.
2. No block of internal/metadata ranges (169.254.169.254, 127./10./172.16-31./192.168., ::1, metadata.google.internal).
3. Hostname validated but not the RESOLVED IP (DNS rebinding / TOCTOU) → resolve-and-pin.
4. Redirects followed to a denied host → maxRedirects 0 / re-validate each hop.
5. Dangerous schemes (file://, gopher://, dict://, data:) → https-only.
6. Cloud metadata reachable / IMDSv1 → IMDSv2 (infra).

## Upload note

Inbound upload (magic-byte/size/path/uuid) owned by backend file-upload + the rule MUST. Security-specific: SVG-as-image (stored XSS), polyglots, native image-parser CVE (ImageMagick/libvips).

## Gotchas

Hardcoded/internal URL ≠ SSRF (only user-controlled). Allow-list is the fix, not a finding. Deny-lists are weak (encodings/rebinding) — allow-list + resolved-IP. Egress NetworkPolicy is defense-in-depth.

## Halt conditions

No finding without the cited sink + user source + fix; no deny-list as the primary control; don't flag hardcoded/allow-listed fetches.

## Related

@security-auditor A01 (dispatches here), backend file-upload (inbound), security-principles, infrastructure (egress policy + IMDSv2).
