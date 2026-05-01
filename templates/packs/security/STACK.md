# Security pack — stack assumption

This pack's rules, agents, skills, and patterns assume:

- **A password-hashing primitive** (`argon2id` preferred, `bcrypt` cost ≥ 12 acceptable)
- **A JWT / session library** with signature + `exp` + `iss` + `aud` verification
- **A schema validator** at every input boundary (zod / class-validator / pydantic / marshmallow / Joi / Bean Validation)
- **A secret manager** integration (AWS Secrets Manager / Vault / Doppler / GCP Secret Manager / 1Password CLI)
- **A secret scanner** in CI (`gitleaks` / `trufflehog`)
- **A SAST tool** (`semgrep` / Snyk Code / SonarQube)
- **A dependency-vuln scanner** (`npm audit` / `pip-audit` / `cargo audit` / `trivy fs` / Snyk / Dependabot)

## Inline examples in this pack

Wherever this pack's files show concrete syntax (decorators, library calls, header values), the syntax is **NestJS + zod / Passport.js** for illustration. Substitute per stack:

| NestJS + Passport (illustrated) | Spring Security (Java) | FastAPI + python-jose | Laravel Sanctum | Django + DRF | Substitution source |
|---|---|---|---|---|---|
| `@UseGuards(JwtAuthGuard)` | `@PreAuthorize("isAuthenticated()")` | `Depends(get_current_user)` | `auth:sanctum` middleware | `IsAuthenticated` permission | auth gate |
| `@Public()` opt-out | `@PermitAll` | route without `Depends` | `Route::get(...)->withoutMiddleware('auth')` | `AllowAny` permission | public-route opt-in |
| `class-validator` DTO | Bean Validation `@Valid` | pydantic `BaseModel` | FormRequest | DRF `Serializer` | input schema |
| `argon2` npm pkg | `BCryptPasswordEncoder` | `passlib.hash.argon2` | `Hash::make` (bcrypt) | `argon2-cffi` | password hash |
| `helmet` middleware | `SecurityFilterChain` headers | `secure` middleware | `secure-headers` package | `django-secure` | security headers |
| `@nestjs/throttler` | Bucket4j / Resilience4j | `slowapi` | `throttle:60,1` | `django-ratelimit` | rate limiter |

## Where stack-specific names live

- The project's `_extracted-idioms.md` — actual auth middleware, validation library, password hasher, secret-manager binding, JWT library, throttle implementation.
- The project's `_extracted-codebase.md § Security` — auth flow location, audit log table, secret-manager integration path.
- CI configuration — `gitleaks`, `semgrep`, `npm audit` / `pip-audit` / `trivy fs` are tool-agnostic; project picks the runners.

The rule's hard rules (auth-on-by-default, parameterized-queries, no `eval`, JWT signature verification) are framework-agnostic — they apply to any stack with the listed primitives.
