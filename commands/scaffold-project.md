---
description: Take a refined idea (or raw prompt) and generate a working project from scratch — proposes stack with rationale, runs official scaffolders, layers clean architecture + design system + auth + dashboard, writes ADRs for every choice, installs Claude orchestration, validates dev server boots.
---

# /scaffold-project "<idea-or-refined-spec-path>"

Idea → working repo. Single command, multiple confirmation gates, opinionated defaults, every choice documented in ADRs.

The output is a project that:
- **Boots locally** out of the box (`pnpm dev` works; smoke test passes).
- **Has Claude Code orchestration installed** (via `/setup-project --create` chain-call).
- **Looks beautiful by default** (Tailwind 4 + Radix + shadcn/reka-ui + lucide icons + 8pt grid + Inter Variable + light/dark theme).
- **Has clean architecture** (layered or modular per stack) with a working auth flow + dashboard scaffold.
- **Documents every choice** as ADRs in `ai/decisions/` so future maintainers know why.

Intentionally opinionated. The choices are based on what ships fast, scales reasonably, and is well-documented in 2026. Override anything before write — every gate has a "change this" path.

## Inputs (one of)

- **Refined spec path**: `ai/ideas/<YYYYMMDD>-<slug>.md` (output of `/refine-prompt`). Preferred path; spec drives every Phase 2 decision.
- **Raw idea string**: `"a marketplace for X"` — command runs an inline mini-refine first, then proceeds.

Optional flags:
- `--name=<repo-name>` — override the slug auto-derived from the idea.
- `--into=<path>` — destination directory (default: `<repo-name>` in `$PWD`).
- `--stack=<key>` — skip the stack picker and force a known preset (`nextjs-saas`, `vite-react-spa`, `nuxt-shop`, `sveltekit-app`, `astro-marketing`, `expo-mobile`, `nest-api`, etc.). Listed in section "Stack presets" below.
- `--no-claude-orchestration` — skip the chained `/setup-project --create` (you'll add it later). Default is to install.
- `--no-prompt` — auto-confirm every gate. Use when scripted; not recommended interactively.
- `--dry-run` — print the entire generation plan and exit without writing anything.

## Pre-flight checks (halt if any fail)

1. Destination dir is empty OR doesn't exist yet. **Refuse to overwrite an existing project** — ask the user to pick a fresh path or run `/setup-project --refresh` instead.
2. `pnpm`, `npm`, `bun`, or `yarn` is on PATH (need at least one to run scaffolders).
3. `git` is on PATH.
4. If the idea path is provided, the file exists and was produced by `/refine-prompt` (validates against expected sections 1-17).
5. Network reachable (`pnpm` will need to fetch packages). Skill issues a warning, not a halt — offline mode is supported via `--no-install`.

## Phases applied

All 7 with **three confirmation gates**:

1. Phase 1 — Understand
2. Phase 2 — Organize (decide stack, architecture, design system, project shape)
3. **Phase 2a gate** — Stack proposal (PAUSE for confirmation)
4. **Phase 2b gate** — Architecture + design system proposal (PAUSE for confirmation)
5. Phase 3 — Retrieve (research framework versions, lib compatibility, design system docs)
6. **Phase 3a gate** — Final plan presentation (PAUSE for confirmation)
7. Phase 4 — Generate (run scaffolders + layer code)
8. Phase 5 — Update (docs, ADRs, Claude orchestration)
9. Phase 6 — Validate (boots, lints, types)
10. Phase 7 — Improve (next-features roadmap)

## Phase 1 — Understand

If input is a refined spec path:
- Read the file. Extract: pitch, problem, personas, jobs, scope IN/OUT, non-functional needs, scale, constraints, deferred decisions (section 17).
- If section 17 names specific stack constraints ("must use Postgres", "no Vercel"), record as **HARD constraints** for Phase 2.

If input is a raw idea string:
- Run an inline mini-refine: 5-question burst (pitch / users / scale / hard constraints / nice-to-haves). The user confirms or edits.
- Save the mini-refined idea to `ai/ideas/<auto-slug>.md` so Phase 2 has a written spec to read.

Restate the project to the user in 4 lines:
```
Domain:       <one phrase>
Audience:     <one phrase>
Scale tier:   <solo / small team / startup / enterprise>
Constraints:  <list or "none">
```

Wait for confirmation OR `--no-prompt`.

## Phase 2 — Organize

### 2.1 — Classify the project shape

| Phase 1 signals | → Project shape |
|---|---|
| Marketing site / brochure / blog | static-content |
| SaaS dashboard / B2B tool | saas-fullstack |
| Marketplace / e-commerce | commerce-fullstack |
| Real-time chat / collaboration | realtime-fullstack |
| Data viz / internal dashboard | data-fullstack |
| Mobile-first consumer app | mobile-app |
| Internal tool with simple CRUD | internal-tool |
| API service (no UI) | api-only |
| Library / SDK | library |

The shape narrows Phase 2.2 to a 3-option ranked stack.

### 2.2 — Propose 3 ranked stacks (Phase 2a gate)

Pick the **default + 2 alternatives** for the project shape. Each option includes: name, rationale, day-1 wins, watch-outs.

#### Stack presets (defaults per shape)

| Shape | #1 default | #2 alternative | #3 alternative |
|---|---|---|---|
| static-content | Astro 5 + MDX + Tailwind 4 | Next 15 (App Router, SSG) | SvelteKit + Tailwind |
| saas-fullstack | Next 15 + Drizzle + Postgres + Better Auth + Stripe | Next 15 + Prisma + Postgres + Clerk + Stripe | SvelteKit + Drizzle + Postgres + Lucia + Stripe |
| commerce-fullstack | Next 15 + Drizzle + Postgres + Stripe + Better Auth | Medusa 2 (commerce-purpose-built) + Next storefront | Shopify Hydrogen (if hosted on Shopify) |
| realtime-fullstack | Next 15 + Convex (BaaS, realtime built-in) | Next 15 + Supabase Realtime + Postgres | SvelteKit + PartyKit + Cloudflare |
| data-fullstack | Next 15 + tRPC + Drizzle + Postgres + Tanstack Table/Charts | Vue 3 + Vite + Pinia + tRPC client | SvelteKit + Tanstack Query + Postgres |
| mobile-app | Expo SDK 53 + React Native + Convex (or Supabase) | Flutter (if iOS+Android first-class is non-negotiable) | Tauri Mobile (if existing web codebase + Rust appetite) |
| internal-tool | SvelteKit + Drizzle + Postgres + Lucia | Next 15 + Drizzle + Postgres + Better Auth | Refine.dev (if mostly admin-CRUD) |
| api-only | Hono + Drizzle + Postgres + Cloudflare Workers | Fastify + Drizzle + Postgres + Node | NestJS + Postgres (if structured / multi-team) |
| library | tsdown + Vitest + Changesets | tsup + Vitest + Changesets | unbuild + Vitest + Changesets |

Print the 3 options with rationale + day-1 wins + watch-outs. **STOP. Wait for the user to pick #1 / #2 / #3 / "describe a different stack".** Do not proceed without explicit pick OR `--no-prompt` (which forces #1).

### 2.3 — Architecture + design system proposal (Phase 2b gate)

Once stack is locked:

**Architecture proposal** — pick based on stack:
- **Layered** (default for most fullstacks): `pages/components → composables/hooks → services → core`
- **Modular** (default for non-trivial SaaS / enterprise): `src/modules/<feature>/{pages,components,services,types,locales}` (matching `tenant-portal-v2` shape)
- **Service-oriented** (default for `api-only`): handlers → services → repositories
- **Atomic Design** (default for marketing / static-content): atoms → molecules → organisms → templates → pages

**Design system proposal**:
- **Library**: Tailwind 4 + Radix Primitives + lucide-react (or lucide-vue / lucide-svelte) + shadcn/ui (React) / reka-ui (Vue) / bits-ui (Svelte).
- **Tokens**:
  - 8pt grid spacing (`--spacing-1: 4px; --spacing-2: 8px; ... --spacing-12: 48px`)
  - HSL color system with semantic tokens (`--color-bg`, `--color-fg`, `--color-accent`, `--color-muted`, `--color-border`, status colors `--color-success/warning/danger/info`)
  - Light + dark theme via CSS custom properties; no JS theme switcher needed for SSR
  - Border radius: `--radius-sm: 6px; --radius-md: 8px; --radius-lg: 12px`
- **Typography**: Inter Variable (system fallback for offline). Display = Inter; Mono = JetBrains Mono.
- **Brand**: ask the user for a single hue (HSL hue rotation) — defaults to `220` (blue) for SaaS, `12` (orange) for commerce, `160` (green) for finance, `280` (purple) for creative tools. The user picks `0-360` or types a name (`blue`, `coral`, `mint`, etc.).

Print the architecture + design proposal. **STOP. Wait for confirmation OR explicit changes.**

## Phase 3 — Retrieve

Once Phase 2 is locked:

- Look up **current latest stable versions** for every dependency in the chosen stack — by reading `package.json` from a freshly scaffolded reference project (`pnpm create <thing>` against a temp dir, or by querying the registry). Pin to versions that exist as of run-time.
- Read official scaffolder docs for the chosen primary tool — stay current with their conventions (e.g., Next 15 App Router shape, Vite 7, Astro 5).
- Read design-system docs for the chosen library — install commands and current component APIs.

### Phase 3a — Final plan gate

Print the **complete generation plan**:

```
Project name:        <slug>
Destination:         <path>
Stack:               <#1 picked> with versions <list>
Architecture:        <layered / modular / service-oriented / atomic>
Design system:       Tailwind 4 + Radix + shadcn-ui + lucide + Inter; brand hue = <h>°
First feature:       Auth (sign-up / sign-in / forgot password) + Dashboard
Database:            <Postgres / SQLite / Convex / MongoDB / etc.>
Migrations:          <Drizzle Kit / Prisma / etc.>
Hosting target:      <Vercel / Cloudflare / Fly / Railway / etc.>
CI:                  GitHub Actions (lint + type + test on every PR)
Claude orchestration: yes / no (--no-claude-orchestration)
ADRs to write:       <count> (one per major choice)
```

**STOP. Wait for "go" OR specific changes.** This is the last gate before any file is written.

## Phase 4 — Generate

In order, with checkpoints:

### 4.1 — Init the repo

```bash
mkdir -p "$DEST" && cd "$DEST"
git init
echo "node_modules\n.env*\ndist\n.next\n.nuxt\n.svelte-kit\nbuild\n.cache\ncoverage\n.DS_Store\n.claude/dev-server.{pid,log}\n.claude/playwright/\n.claude/backups/" > .gitignore
```

### 4.2 — Run the official scaffolder for the chosen stack

Examples (one runs based on Phase 2 pick):

| Stack | Command |
|---|---|
| Next 15 App Router | `pnpm create next-app@latest . --ts --tailwind --eslint --app --src-dir --import-alias "@/*" --no-git` |
| Vite + React | `pnpm create vite@latest . --template react-ts` |
| SvelteKit | `pnpm create svelte@latest .` (then auto-pick: Skeleton + TS + ESLint + Prettier + Vitest + Playwright) |
| Nuxt 3 | `pnpm create nuxi-app@latest .` |
| Astro | `pnpm create astro@latest . --template basics --typescript strict --install --no-git` |
| Expo | `pnpm create expo-app@latest . --template default` |
| Hono | `pnpm create hono@latest . --template cloudflare-workers` |
| NestJS | `pnpm dlx @nestjs/cli new . --strict` |

Verify the scaffolder succeeded (exit code 0) before continuing.

### 4.3 — Install design system

For React stacks:
```bash
pnpm add tailwindcss@latest @tailwindcss/vite postcss autoprefixer
pnpm add @radix-ui/react-slot @radix-ui/react-dialog @radix-ui/react-dropdown-menu lucide-react clsx tailwind-merge class-variance-authority
pnpm dlx shadcn@latest init -d
pnpm dlx shadcn@latest add button input label card dialog dropdown-menu form sheet separator tooltip toast
```

For Vue stacks:
```bash
pnpm add tailwindcss@latest @tailwindcss/vite
pnpm add reka-ui lucide-vue-next clsx tailwind-merge class-variance-authority
```

For Svelte stacks: similar pattern with `bits-ui` + `lucide-svelte`.

Write the tokens (CSS custom properties for spacing, colors, radii, fonts) into `src/app.css` or equivalent, with light + dark themes.

### 4.4 — Write the architecture skeleton

Create the directory layout per the chosen architecture:

**Modular example (matches the patterns this user is already using elsewhere):**
```
src/
├── core/                       # framework-agnostic primitives
│   ├── api/                    # HTTP client (one apiClient + one publicClient)
│   ├── types/                  # shared types
│   └── utils/                  # pure utilities
├── shared/                     # cross-module reuse
│   ├── components/             # design-system-extending components
│   ├── composables/ (hooks/)   # cross-module composables
│   ├── locales/                # cross-cutting i18n keys
│   └── utils/                  # shared utilities
├── modules/                    # feature modules
│   ├── auth/
│   │   ├── pages/
│   │   ├── components/
│   │   ├── composables/        # or hooks/ for React
│   │   ├── services/
│   │   ├── types/
│   │   ├── locales/
│   │   ├── routes.ts
│   │   └── api.ts
│   └── dashboard/
│       └── ...
└── store/                      # global state if applicable
```

For **layered** architectures the layout is shallower; for **service-oriented** it's `routes/ → services/ → repositories/`.

### 4.5 — Build the auth + dashboard scaffold

The first running feature, regardless of project shape:

- **Auth** (sign-up + sign-in + forgot-password):
  - For Next + Better Auth: install Better Auth, configure with email/password + OAuth Google, scaffold `app/auth/sign-in/page.tsx`, `app/auth/sign-up/page.tsx`, `app/auth/forgot-password/page.tsx`. Wire middleware for protected routes.
  - For Next + Clerk: install `@clerk/nextjs`, wrap layout, add sign-in/up routes via Clerk components.
  - For Vue + Lucia: install Lucia + adapter, scaffold a session helper, build sign-in/up pages.
  - Use design-system primitives (Button, Input, Label, Card, Form) — never raw HTML.

- **Dashboard scaffold**:
  - Sidebar layout with navigation (Home / Settings / Account).
  - Welcome card with the user's name.
  - One stub data card ("0 items" — placeholder for the user's first feature).
  - Empty state design that's beautiful (illustration + helpful CTA).

This is the floor — every project boots with login working, you can land on a dashboard.

### 4.6 — Database + ORM

If Phase 2 picked a database:

```bash
pnpm add drizzle-orm pg               # for Postgres
pnpm add -D drizzle-kit @types/pg
```

Write `drizzle.config.ts`. Create initial schema with the auth tables Better Auth / Lucia needs. Run an initial migration.

### 4.7 — CI / testing / quality

- `vitest.config.ts` (or jest.config.ts) — set up unit testing.
- `playwright.config.ts` — set up e2e (Playwright is pre-installed via `verify-with-playwright` skill).
- `.github/workflows/ci.yml` — lint + type-check + unit tests + e2e on PR.
- `husky` + `lint-staged` for pre-commit.
- ESLint + Prettier configured.

### 4.8 — Layer Claude Code orchestration

Unless `--no-claude-orchestration` was passed:

```bash
# This invocation creates .claude/, ai/, CLAUDE.md, runs preflight + applies pack
# content scoped to the detected stack via M28 detect-tracks.
~/.claude/scripts/run-preflight.sh "$DEST" --mode=create
# Then the agent runs the rest of /setup-project --create logic in this session
# (writing the orchestration files, anchoring artifacts via apply-anchors.sh,
# generating .mcp.json via detect-mcp.sh --apply).
```

After this step the new project has the FULL orchestration layer — agents, skills, rules, patterns, MCP servers, all scoped to its stack.

### 4.9 — ADRs

Write one ADR per major choice in `ai/decisions/`:
- `0001-stack.md` — "Why <framework> over the alternatives we considered."
- `0002-architecture.md` — "Why <layered/modular/service> for this domain."
- `0003-design-system.md` — "Why Tailwind + Radix + shadcn/reka + lucide; brand hue."
- `0004-database.md` — "Why <Postgres/SQLite/Convex>" + ORM choice.
- `0005-auth.md` — "Why <Better Auth/Clerk/Lucia>."
- `0006-deployment.md` — "Why <Vercel/Cloudflare/Fly>."

Each ADR follows the template: Context → Decision → Consequences → Alternatives considered.

## Phase 5 — Update

- `README.md` — generated with project pitch, run instructions, architecture overview, ADR index.
- `CLAUDE.md` — generated by the chained `/setup-project --create` (already wired in Phase 4.8).
- `ai/status.md` — initial status: `Phase: scaffolding-complete; next: build core feature 1`.
- `ai/dynamic/changelog.md` — entry: `project scaffolded`.
- `.env.example` — every secret/var the stack needs (DATABASE_URL, AUTH_SECRET, NEXT_PUBLIC_*, etc.) with safe defaults / placeholders.

## Phase 6 — Validate

In order — refuse to declare success on any failure:

1. **Lint**: `pnpm lint` exits 0.
2. **Type-check**: `pnpm type-check` (or `tsc --noEmit`) exits 0.
3. **Unit tests**: `pnpm test` exits 0 (the scaffold has 1-2 trivial tests; they pass).
4. **Dev server boots**: `dev-server-start` skill confirms server returns 200 within 60s.
5. **Auth flow renders**: Playwright MCP navigates to `/auth/sign-in`, asserts heading visible, screenshots.
6. **Dashboard renders** (after a test login): Playwright navigates to `/dashboard`, asserts the welcome card visible.
7. **No console errors** on either page.
8. **Anchoring audit** (post-orchestration): `audit-anchoring.sh` shows every pack-derived artifact carries a project-specific block. (Phase 4.6 of the chained `/setup-project --create` does this; we just verify.)
9. **Initial commit**: `git add . && git commit -m "chore: scaffold via /scaffold-project"` — the new repo has a clean root commit.

If any step fails: print the specific failure, leave the dir in a usable state (don't auto-rollback), surface to user.

## Phase 7 — Improve

Generate `ai/dynamic/next-features.md` — a prioritized roadmap drawn from the refined spec's section 5 (MVP scope IN):

```markdown
# Next features — <project>

> Generated from ai/ideas/<slug>.md § 5 (MVP scope IN).
> Each feature here can be implemented via `/add-feature "<name>"`.

## Sprint 1 (foundation)
- [ ] <feature 1 — short-form>
- [ ] <feature 2 — short-form>

## Sprint 2 (core flows)
- [ ] <feature 3>
- [ ] <feature 4>

## Sprint 3 (polish + scale)
- [ ] <feature 5>

## Deferred (post-MVP — from spec § 6 anti-goals)
- <stuff explicitly out of scope, listed so we don't forget why>
```

Suggest the natural next command:
```
Next: `/add-feature "<feature 1 name>"` to ship the first feature.
```

## Output format

```
## /scaffold-project — <slug>

Phase 1 (Understand): <domain> for <audience>; constraints = <list>
Phase 2 (Organize):
   Stack:        <#1 picked from 3 ranked options>
   Architecture: <picked>
   Design:       Tailwind + Radix + shadcn/reka + lucide; brand hue = <h>°
Phase 3 (Retrieved): N package versions pinned; M docs read
Phase 4 (Generated):
   Repo:           <files written count>
   Architecture:   src/{core,shared,modules}/...
   Design system:  installed + tokens written
   Auth + dashboard: scaffolded
   Database:       <db> + initial schema + migration applied
   CI:             GitHub Actions config written
   Claude orchestration: <yes/no>
   ADRs:           N written
Phase 5 (Updated): README, CLAUDE.md, status, changelog, .env.example
Phase 6 (Validated):
   Lint:        ✓
   Type-check:  ✓
   Tests:       ✓ <count> passing
   Dev server:  ✓ booted on port <p>
   Auth route:  ✓ renders
   Dashboard:   ✓ renders
   Console:     ✓ no errors
   Anchoring:   ✓ <coverage>%
Phase 7 (Improved): ai/dynamic/next-features.md written; <count> features queued

Status: SCAFFOLDED — ready to build features
Repo:   <path>
Boot:   `cd <path> && pnpm dev`  (port: <p>)
Next:   `/add-feature "<first feature>"`
```

## Failure modes

- **Destination not empty** → refuse to overwrite. Don't auto-pick a sibling dir; ask the user.
- **Network unreachable + `--no-install` not passed** → halt before scaffolder run; suggest `--no-install` for offline mode.
- **Scaffolder exits non-zero** → don't continue. Capture the scaffolder's output, surface, halt. Don't pretend success.
- **User picks a stack we don't know** ("describe a different stack" branch) → architect agent + research mode; takes longer; runs Phase 3 deeper. NEVER fabricate an unknown stack — tell the user we'd need to research and confirm before generating.
- **Three confirmation gates skipped via `--no-prompt`** → log heavily; first commit message says `[--no-prompt] confirmed defaults: <stack> + <arch> + <design>` so the user has audit trail.
- **Validation Phase 6 fails on a fresh scaffold** → either the scaffolder is broken (unlikely; pinned versions) or our layer-on broke something. Halt + surface; don't auto-rollback (user may want to inspect).
- **`--no-claude-orchestration` skipped, then user runs `/setup-project --refresh`** → behavior fully supported; M28 detect-tracks scopes correctly. No special logic needed.
- **Refined spec section 17 forbids a Phase 2 default** ("must NOT use Vercel") → respect HARD constraints. Re-rank stack options to remove the forbidden choice.

## Hard rules

- **Three confirmation gates between Phase 2a / 2b / 3a.** Skipping any of them produces a project the user didn't actually want. `--no-prompt` is logged in the first commit.
- **Default to opinionated, not maximally configurable.** Tailwind 4 + Radix + shadcn/reka + lucide + Inter is the floor — chosen because it ships beautiful UIs in days, not weeks. Override per-idea but don't water down the default.
- **Run real scaffolders.** `pnpm create <thing>` is more current and better-maintained than any custom template. We layer Claude orchestration on top; we don't replace the ecosystem.
- **Pin versions at scaffold time.** Read what `pnpm create` wrote and freeze. Future `pnpm update` is the user's choice.
- **One ADR per major decision.** "Why React over Vue" / "Why Postgres over Mongo" — answered in writing or it's not a real decision.
- **Validation phase is non-negotiable.** A scaffold that doesn't boot is worse than no scaffold. If Phase 6 can't pass, Phase 7 doesn't run.
- **Refuse to overwrite an existing project.** No `--force-overwrite`. Use a fresh dir or `/setup-project --refresh` on the existing one.
- **No secret values in committed files.** `.env.example` only; the scaffold prints what to put in `.env.local` for the user to fill manually.
- **Never assume the user picked the default.** Even with `--no-prompt`, the first commit message names exactly which option was chosen so the trail is auditable.
- **Implementation tools are the ones running, not us imitating them.** When the scaffolder has an interactive prompt, we pass exact CLI flags to make it non-interactive. We don't reimplement what `create-next-app` already does well.

## Stack-awareness

This command assumes generic web/mobile/api shapes. Specific tweaks:

- **Mobile (Expo)**: `pnpm dev` is `pnpm start` in Expo's vocabulary; Phase 6 dev-server-start skill detects + adapts.
- **Astro**: no auth scaffold by default (mostly static); a "newsletter signup" component substitutes if backend is involved.
- **API-only**: no design-system layer; Phase 4.3 is skipped. A request/response example client + OpenAPI spec replace the "dashboard renders" check.
- **Library**: scaffolder writes nothing UI; Phase 4.5/4.6 are skipped. Phase 6 validates `pnpm build` produces a valid dist + `pnpm test` passes.

## Related

- `/refine-prompt` — the natural prior step. Produces the refined spec this command consumes.
- `/setup-project --create` — chained automatically in Phase 4.8 unless `--no-claude-orchestration`. Installs the orchestration layer.
- `/add-feature` — the natural next step after scaffold. Builds the first MVP feature using the now-installed orchestration.
- `/setup-project --refresh` — what you run later when stack/conventions evolve and you want re-detected pack content.
