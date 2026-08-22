---
name: zero-trust
kind: example
pack: security
---

# Pattern: Zero-Trust Architecture

> **Hard rule** — Every service boundary authenticates the caller; no boundary trusts the network. Long-lived API keys, "internal = trusted" assumptions, and shared credentials across environments are forbidden.

**Halt conditions / mandatory cites**
- Cite the workload-identity issuer (SPIFFE / cloud IAM / K8s ServiceAccount config) as `<path:line>`; a shared API key in an env var is a halt, not an identity.
- Cite the secrets-manager binding as `<path:line>`; env-var secrets committed to the repo are forbidden.
- Cite the tenant-scoping enforcement point as `<path:line>`. **Engine-conditional:** where the engine ships no row-policy feature, the absence of a DB layer is graded as an accepted limit with compensating controls, never an unfixable finding (see `tenant-isolation.md § The below-app layer`); app-layer scoping applied per-query instead of by construction IS a halt.
- Cite the audit-log emitter for privileged actions as `<path:line>`; a privileged action with no audit row is a halt.
- Hand-wave grep ban — never claim "no long-lived keys" without citing the rotation policy file or the secret-scan CI rule.

## The one claim

**Possession of a network position is not a credential.** For each boundary ask: what would an attacker already inside the network need to forge? If the answer is "nothing — they'd just call it", the boundary does not exist.

## Boundaries and what each one verifies

| Boundary | Caller presents | Receiver verifies | The probe that proves it |
|---|---|---|---|
| Internet → edge | User credential / session | TLS terminated; signature + expiry + issuer + audience | Replay an expired token → 401, not 200 |
| Service → service | Workload identity (mTLS cert, SVID, cloud IAM token, signed JWT/HMAC) | Issuer + subject + audience; subject on the receiver's allow-list | Call from an unrelated pod/host with no identity → refused |
| Human → privileged action | Session + second factor | Step-up performed for THIS action, not just at login | Act on a session that never stepped up → denied |
| App → data store | A per-service, scoped DB principal | Read-only grants where reads suffice; tenant scope by construction | Write on a read path's credential → permission denied |
| Build → runtime | Signed artifact + pinned digest | Signature verified at admission; digest matches | Deploy an unsigned image → admission rejects |

The vendor implementing a row belongs in an ADR. What is not optional: all three columns filled with a `<path:line>`.

## Adoption order

**Tier 1 — before production traffic.** TLS everywhere. Short-lived tokens + refresh rotation. MFA on admin. Secrets in a manager. Tenant scoping enforced **by construction** at the data layer. Containers non-root + read-only FS.
**Tier 2 — at the second service.** Workload identity (retires the shared API key). Default-deny network policy. Audit logs on privileged ops. Dependency scanning in CI. SBOM per build.
**Tier 3 — mature.** mTLS via mesh. Short-lived certs, automated rotation. **Engine-enforced row policies where the engine has them** — belt over tier 1's suspenders, never a replacement. Signed artifacts verified at admission.

> Tier 1 and tier 3 tenant isolation are different controls: tier 1 is *the app cannot forget the filter*; tier 3 is *the engine refuses the row even if the app forgot*. Only tier 1 is universally available.

## Forbidden

- "Trust the VPN" / "internal network" as a primary defense.
- Long-lived API keys; any credential shared across dev/staging/prod.
- One perimeter break equalling full compromise.
- All-permissions admin roles where a scoped role would do; MFA optional for privileged users.
- "We'll encrypt it later" for new PII.

## Related

`auth-flow.md` (user-facing half) · `tenant-isolation.md` (data-layer boundary, engine capability) · `security-principles.md` · `@security-auditor`, `@tenant-isolation-reviewer`.
