---
name: env-diff
description: Compare .env against .env.example — flag missing keys (will break at runtime), orphan keys (dead config), and unvalidated keys (not in the env schema).
---

# env-diff

Config bugs are a top-5 cause of "it works on my machine". Surface missing / orphan / unvalidated env keys before boot.

## When to use

- After pulling a branch that may have added env vars.
- After editing `shared/config/env.schema.ts` (joi/zod) — verify schema, example, and live `.env` agree.
- Before onboarding a new dev.
- In CI as a pre-deploy gate.

## Prerequisites

- `comm` and `awk` (POSIX; preinstalled on macOS/Linux).
- The repo's env schema file path (commonly `shared/config/env.schema.ts`, `apps/*/src/config/env.validation.ts`).

## Procedure

1. Locate env file pairs in the repo:
   ```bash
   ls -1 .env* 2>/dev/null
   ```
   Single-app: `.env` + `.env.example`. Multi-app (e.g., master + tenant): also `.env.tenant` + `.env.tenant.example`.
2. Extract key sets from each file:
   ```bash
   keys() { grep -oE '^[A-Z][A-Z0-9_]+' "$1" | sort -u; }
   ```
3. Diff example vs live for each pair:
   ```bash
   comm -23 <(keys .env.example) <(keys .env)   # MISSING in live
   comm -13 <(keys .env.example) <(keys .env)   # ORPHAN in live
   ```
4. Cross-check example keys against the env schema validator (joi/zod/pydantic-settings) — keys present in example but absent from schema are UNVALIDATED.
5. Classify boot risk: any MISSING key referenced as `required` in the schema = HIGH (boot will fail).

## Output

```
Env diff — .env vs .env.example

MISSING (4):
  ANTHROPIC_API_KEY
  WHATSAPP_APP_SECRET
  REDIS_URL
  DATABASE_URL

ORPHAN (2):
  OLD_API_KEY               (remove from .env — no longer used)
  DEBUG_MIGRATION_TRACE     (remove from .env.example — only for one-off debug)

UNVALIDATED (1):
  CUSTOM_FEATURE_FLAG       (add to shared/config/env.schema.ts)

Boot risk: HIGH (4 required keys missing — app won't start).
```

## False positives / gotchas

- Comments and blank lines — strip with the `^[A-Z]` anchor in `keys()`.
- `KEY=` (set but empty) is valid syntax but often a misconfiguration — flag empty values separately if the schema requires non-empty.
- Multi-line values (e.g., `PRIVATE_KEY="-----BEGIN..."`) require careful parsing — `dotenv-cli`'s parser is more accurate than naive grep.
- NEVER print VALUES — only keys. Values may be secrets.
- `.env` MUST stay gitignored. If it shows up in `git status`, stop and check `.gitignore`.
