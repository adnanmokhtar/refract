# `project_kind:` — the artifact-level applicability gate

## Why this exists

Packs are selected per TRACK, and a track is a whole folder. `performance` is a legitimate track
for a headless API and for a browser SPA alike — but half its artifacts are about the browser and
half are about the server, and until this key existed there was no way to say so. The result,
measured on a live NestJS service with zero UI:

| Installed on a repo that renders nothing | Bytes |
|---|---|
| `.claude/commands/bundle-perf.md` — *"Web bundle + page-load performance audit. Bundle size, JS execution, rendering, hydration."* | 21,795 |
| `.claude/ai-patterns/lazy-loading.md` — *"defer loading of code, data, images, components"* | 11,277 |
| `.claude/skills/web-vitals-field/SKILL.md` — *"Lab tools cannot field-measure INP"* | 8,232 |
| `.claude/ai-patterns/inp-responsiveness.md` — *"main-thread work under the INP budget … LoAF"* | 8,146 |

**49,450 bytes — 17.6% of everything that run installed — on a repo where `git ls-files | grep -c
'\.vue$'` is 0, `.tsx` is 0, and package.json names no frontend framework.** `bundle-perf.md` was
the single largest command the run installed. The track selector had no project-kind filter, so
whole-pack application was all-or-nothing.

## The contract

Any pack artifact may declare, in its frontmatter:

```yaml
project_kind: browser        # one of: browser | server | mobile | cli | any (default)
```

Semantics — deliberately narrow, so this key can never become a second track system:

* **`any`** (the default when the key is absent) — install whenever the track is selected.
  Every existing artifact keeps its current behaviour; adding this key changed nothing by default.
* **`browser`** — install only when the target has a rendered UI layer.
* **`server`** — install only when the target has a server/API layer.
* **`mobile`** — install only when the target has a native or React Native / Flutter layer.
* **`cli`** — install only when the target's primary deliverable is a command-line binary.

A row whose declared kind does not match the target is **declined, not missing**: it is reported
the same way a ledger decline is, so it never counts as a coverage gap and never re-proposes.

## Detecting the target's kinds

A repo can be several kinds at once (a fullstack monorepo is `browser` *and* `server`), so the
target carries a SET and a row matches when its kind is in that set. The detector is shell,
lives in `scripts/detect-project-kind.sh`, and is deliberately dependency-based rather than
prose-based:

* `browser` — a frontend framework dependency (react / vue / angular / svelte / solid / astro /
  nuxt / next / remix), or any `.vue` / `.tsx` / `.jsx` / `.svelte` source file, or an
  `index.html` outside `node_modules`.
* `server` — a backend framework dependency (nest / express / fastify / koa / hapi / fastapi /
  django / flask / rails / laravel / spring / gin / echo / phoenix), or a Dockerfile that
  EXPOSEs a port, or a `main.go` / `manage.py` / `artisan`.
* `mobile` — `react-native` / `expo` dependency, `pubspec.yaml`, `*.xcodeproj`, or an
  `android/build.gradle`.
* `cli` — a `bin` map in package.json, a `[project.scripts]` / `console_scripts` entry, or a
  `cmd/` directory beside a `go.mod`.

When the detector resolves NOTHING, every kind matches. An undetectable repo must not be
silently stripped of half its artifacts — that would trade one silent wrong for another.

## Adding the key to an artifact

Only when the artifact is *unusable* outside that kind, not merely *most useful* there. The test
is: could a competent engineer on the other kind of project act on this file at all? A pattern
about queue backpressure is useful to a browser app talking to a queue; a skill whose entire
subject is measuring INP in a browser is not usable by a service with no browser.

`scripts/validate-pack-consistency.sh` fails the build on an unknown `project_kind:` value, and
`scripts/lint-setup-contracts.sh § rule 5` fails it if an artifact whose text is unmistakably
browser-only ships without the key.
