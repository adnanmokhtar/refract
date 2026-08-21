---
name: zero-trust
kind: example
pack: security
---

# Pattern: Zero-Trust Architecture

> **Hard rule** — Every service boundary authenticates the caller; no boundary trusts the network. Long-lived API keys, "internal = trusted" assumptions, and shared credentials across environments are forbidden.

**Halt conditions / mandatory cites**
- Cite the workload-identity issuer (SPIFFE / IAM / K8s ServiceAccount config) as `<path:line>` before claiming service-to-service zero-trust; shared API keys are a halt.
- Cite the secrets-manager binding as `<path:line>` (Vault policy file, IAM role, K8s SA); env-var secrets in code are forbidden.
- Cite the row-level isolation rule as `<path:line>` (RLS policy SQL or repository base class); app-only filtering without DB defense-in-depth is a halt for tenant data.
- Cite the audit-log emitter for privileged actions as `<path:line>`; privileged action without an audit row is a halt.
- Hand-wave grep ban — never claim "no long-lived keys" without citing the rotation policy file or secret-scan CI rule.

"Never trust, always verify." Perimeter security dies when apps go multi-service, cloud, remote. Zero trust assumes the network is hostile everywhere.

## Core principles

1. **Verify explicitly** — every request, not just at the front door.
2. **Least privilege** — users, services, and jobs get minimum needed access.
3. **Assume breach** — design so one compromised component doesn't cascade.

## Practical application

### At the edge (ingress)
- TLS everywhere (cert rotation automated).
- WAF (Cloudflare, AWS WAF) for common attacks.
- Rate limiting by IP + by authenticated identity.
- Bot detection (Turnstile, reCAPTCHA, hCaptcha) on high-risk endpoints.

### At every service boundary
- **mTLS** for service-to-service (not just "trust the internal network"). Managed by service mesh (Istio, Linkerd) OR SPIFFE.
- **Short-lived tokens** — access tokens < 15 min, refreshed.
- **Signed requests** between services (JWT or HMAC), verified on receipt.
- **No "internal network = trusted"**. A VPN breach = everything breached otherwise.

### For users
- **MFA** for admin / high-risk accounts. Strongly recommended for all.
- **Session tied to device fingerprint** where feasible. New device = re-verify.
- **Geographic anomaly detection** — login from unexpected country = step-up auth.
- **Session management** — revocable server-side (don't rely on JWT expiry alone).

### For machines / services
- **Workload identity** — services authenticate via SPIFFE / K8s ServiceAccounts / cloud IAM, not shared secrets.
- **Short-lived certs** (hours or days). Cert rotation automated.
- **Scoped tokens** — a service account can only access what it needs.

### At the data layer
- **Row-level security** in the DB (Postgres RLS) as a belt-and-suspenders check on top of app-level filtering.
- **Tenant isolation** enforced at every query.
- **Read-only replicas** for analytical access — no writes possible.
- **Encryption at rest** for sensitive data. Key management via KMS (AWS KMS, GCP KMS, Vault).
- **Field-level encryption** for PII + payment data beyond storage-level encryption.

### At the code level
- **SBOM** (Software Bill of Materials) for every build — know what's in your artifacts.
- **Dependency pinning** + automated vulnerability scanning (Dependabot, Renovate, trivy).
- **Signed commits** + signed release artifacts (cosign, sigstore).
- **Code signing** for internal packages / Docker images.

### At runtime
- **Principle of least privilege** containers — non-root, read-only FS, drop all capabilities.
- **Network policies** (K8s NetworkPolicy / Calico) — default-deny, explicit allows.
- **Secrets rotated** automatically (Vault, AWS SM with rotation enabled).
- **Audit logs** for every privileged action.

## Progressive adoption

You don't implement zero trust overnight. Priority order:

### Tier 1 (do first)
- TLS everywhere (no HTTP in prod).
- Short-lived access tokens + refresh rotation.
- MFA on admin accounts.
- Secrets in a manager (not env vars / files committed).
- Row-level tenant isolation at the DB.
- Container non-root + read-only FS.

### Tier 2 (when growing)
- Service-to-service auth with workload identity.
- NetworkPolicy per namespace.
- Vuln scanning in CI.
- SBOM generation.
- Audit logs for privileged operations.
- Geographic anomaly detection for user logins.

### Tier 3 (mature)
- mTLS via service mesh.
- Short-lived certs rotated hourly.
- Row-level security in DB.
- Signed commits + artifacts.
- Automated secret rotation.
- Continuous compliance scanning (CIS benchmarks).

## Common mistakes

- "Internal = trusted" — once a bastion is breached, everything falls.
- Long-lived API keys — rotation forgotten → still valid after employee leaves.
- Default admin credentials in dev/staging that leak to prod.
- "We'll add auth later" — auth retrofit is painful + often incomplete.
- Ignoring supply chain (dep scanning) until exploited.
- MFA only for external users, not internal.

## Threat models that zero trust defends

- Compromised internal service (attacker uses it to pivot).
- Stolen laptop with cached credentials.
- Phished employee credentials.
- Malicious insider.
- Supply chain attack (malicious dep).
- Misconfigured cloud resource (public S3 bucket).

## Tools

- **Service mesh**: Istio, Linkerd, Consul Connect — mTLS + policy enforcement.
- **Identity**: SPIFFE/SPIRE, HashiCorp Boundary.
- **Secrets**: Vault, AWS Secrets Manager, GCP Secret Manager.
- **Policy**: OPA (Open Policy Agent), Kyverno.
- **Scanning**: Trivy, Snyk, Dependabot, cosign.

## Forbidden

- "Trust the VPN" as a primary defense.
- Long-lived API keys.
- Environments (dev/staging/prod) sharing credentials.
- Single break in perimeter = full system compromise.
- Admin roles with everything permissions (build scoped roles).
- MFA as optional for privileged users.
- "We'll encrypt it later" for new PII.
