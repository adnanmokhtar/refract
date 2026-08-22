---
name: zero-trust
description: "Pattern: Zero-Trust Architecture"
kind: ai-pattern
pack: security
---

# Pattern: Zero-Trust Architecture

> **Hard rule** — Every service boundary authenticates the caller; no boundary trusts the network. Long-lived API keys, "internal = trusted" assumptions, and shared credentials across environments are forbidden.

**When to apply**
- Multi-service architecture in cloud or hybrid environments.
- Compliance regime (SOC2, ISO 27001, HIPAA, PCI) requires explicit auth between components.
- Remote / hybrid workforce — VPN-as-perimeter is no longer a defensible boundary.

**When NOT to apply**
- Pre-PMF single-service prototype — adoption tier 1 only (below).
- Static site with no backend secrets — most of zero-trust is overhead.
- Air-gapped on-prem deployment with hardware perimeter — different threat model.

**Halt conditions / mandatory cites**
- Cite the workload-identity issuer (SPIFFE / cloud IAM / K8s ServiceAccount config) as `<path:line>` before claiming service-to-service zero-trust; a shared API key in an env var is a halt, not an identity.
- Cite the secrets-manager binding as `<path:line>` (Vault policy file, IAM role, K8s SA); env-var secrets committed to the repo are forbidden.
- Cite the tenant-scoping enforcement point as `<path:line>` (repository base class, or the engine's row-policy DDL where the engine has one). **Engine-conditional:** where the engine ships no row-policy feature, the *absence* of a DB layer is graded as an accepted limit with compensating controls, never as an unfixable finding — see `tenant-isolation.md § The below-app layer`. What IS a halt: app-layer scoping applied per-query instead of by construction, so a single forgotten call leaks.
- Cite the audit-log emitter for privileged actions as `<path:line>`; a privileged action with no audit row is a halt.
- Hand-wave grep ban — never claim "no long-lived keys" without citing the rotation policy file or the secret-scan CI rule.

## The one claim

**Possession of a network position is not a credential.** Everything below is a consequence. If a request can reach a service, that fact proves nothing about who sent it, so every boundary re-authenticates — including the ones inside your own VPC, cluster, or VPN.

Read that as a test, not a slogan: for each boundary, ask *what would an attacker who is already inside the network need to forge?* If the answer is "nothing — they'd just call it", the boundary does not exist.

## Boundaries and what each one verifies

Every row is the same shape: the caller presents something unforgeable, the receiver verifies it *itself*, and there is an observable failure that proves the check is real. A boundary with no third column is aspirational.

| Boundary | Caller presents | Receiver verifies | The probe that proves it |
|---|---|---|---|
| Internet → edge | User credential / session | TLS terminated, signature + expiry + issuer + audience on the token | Replay an expired token → 401, not 200 |
| Service → service | Workload identity (mTLS cert, SPIFFE SVID, cloud IAM token, signed JWT/HMAC) | Issuer + subject + audience; the subject is on this receiver's allow-list | Call the receiver directly from an unrelated pod/host with no identity → refused |
| Human → privileged action | Session + a second factor (prefer phishing-resistant) | Step-up performed *for this action*, not just at login | Perform the action on a session that never stepped up → denied |
| App → data store | A per-service DB principal, scoped | Grants are read-only where reads suffice; the tenant scope is applied by construction | Attempt a write on a read path's credential → permission denied |
| Build → runtime | Signed artifact + pinned digest | Signature verified at admission; digest matches | Deploy an unsigned image → admission rejects it |

The vendor that implements a row is a project choice and belongs in an ADR, not here. What is *not* a choice: each row needs all three columns filled with a `<path:line>`.

## Adoption order

Tiers are cost-ordered, not importance-ordered — do tier 1 before tier 2 even when a tier-2 item looks more impressive.

**Tier 1 — before any production traffic.** TLS everywhere. Short-lived access tokens + refresh rotation (`auth-flow.md`). MFA on admin accounts. Secrets in a manager, never committed. **Tenant scoping enforced by construction at the app's data layer** (the base repository, not per-query). Containers non-root + read-only FS.

**Tier 2 — when the second service appears.** Service-to-service auth via workload identity (this is what retires the shared API key). Default-deny network policy per namespace. Audit logs on privileged operations. Dependency scanning in CI (`deps-audit`). SBOM per build.

**Tier 3 — mature.** mTLS via a mesh. Short-lived certs with automated rotation. **Engine-enforced row policies as a second isolation layer, where the engine has them** — this is the belt over tier 1's suspenders, not a replacement for it, and it is tier 3 precisely because it is unavailable on some engines. Signed commits + artifacts, verified at admission. Continuous compliance scanning.

> Tenant isolation appears in tier 1 **and** tier 3 on purpose, and they are different controls: tier 1 is *the app cannot forget the filter*, tier 3 is *the engine refuses the row even if the app forgot*. Only tier 1 is universally available. Do not read the tier-3 line as permission to defer tier 1.

## Forbidden

- "Trust the VPN" / "it's on the internal network" as a primary defense.
- Long-lived API keys, and any credential shared across dev / staging / prod.
- A single perimeter break equalling full compromise — that is the definition of the model this pattern replaces.
- Admin roles with all permissions where a scoped role would do.
- MFA optional for privileged users.
- "We'll encrypt it later" for new PII.

## Related

- `ai/patterns/auth-flow.md` — the user-facing half (tokens, refresh rotation, MFA/passkeys) this architecture wraps.
- `ai/patterns/tenant-isolation.md` — the data-layer boundary in depth, including which engines can enforce layer 3.
- `.claude/rules/security-principles.md` — the MUSTs behind these boundaries (TLS, secrets in a manager, authz after authn).
- `@security-auditor` — audits code/infra against this model; `@tenant-isolation-reviewer` — the data-layer deep dive.
