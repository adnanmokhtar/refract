---
description: Upgrade one dependency, framework or runtime to a named version — any ecosystem, any stack. Trigger on 'upgrade X to N', 'bump the major', 'move to Tailwind 4'. Official guide, official codemod, parity proved against a named oracle. Not a V1→V2 port (/migrate), not vuln triage (/dependency-vuln-check).
compatibility: Any stack, any ecosystem — the manifest + lockfile pair and the parity oracle are detected per PROJECT_KIND, not assumed. Requires a package manifest under version control and a clean tree. Runtime-class upgrades additionally require the CI / container / deployment pins to be in this repo, or the run halts rather than shipping a local-only upgrade.
kind: command
pack: orchestration
version: 1.0.0
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /upgrade-dep <target>[@<version>] [<flags>...]

## What this does

**Single command. Move one dependency — or the runtime under it — from the version you have to the version you named, and prove nothing broke.** Deep multi-agent: classify → source the breaking changes → pin a parity oracle → apply (codemod first) → sweep the residue → verify against the oracle → staged commits → brief report.

**An upgrade is not a version-number edit. It is a behaviour-preservation claim**, and a claim is only as good as the evidence behind it. Two things decide whether that claim can be made honestly, and this command refuses to run without settling both:

1. **An authoritative breaking-change source** — the vendor's upgrade guide, release notes, or CHANGELOG for the exact version span. Not recollection. A model's memory of a framework's major release is the single most common way an upgrade ships a silently-removed API.
2. **A parity oracle** — the concrete thing that fails if the upgrade broke something. Tests, a build, a route sweep, a booted app, a rendered screen, an exported-symbol diff. A project with **no** oracle does not get a silent pass; it gets the cheapest oracle proposed and installed first.

Everything else in this command is the discipline that keeps those two honest across ecosystems.

**Discipline:** MUST read [`templates/governance/core-discipline.md`](../templates/governance/core-discipline.md) before writing any fix by hand. MUST read [`templates/packs/migration/rules/migration-discipline.md`](../templates/packs/migration/rules/migration-discipline.md) — the staged-commit + rollback discipline is the same one a V1→V2 port uses, at one-package scale.

## When to use

- "Upgrade Tailwind CSS 3 to 4." / "Move us to React 19." / "Bump Laravel to the next LTS, or Django to the current release." → `/upgrade-dep <name>@<version>`
- "Get us off the Node 18 runtime before it goes EOL." → `/upgrade-dep node@22 --runtime`
- "Flutter 3.35 → 3.38 across the mobile app." → `/upgrade-dep flutter@3.38 --runtime`
- "Everything that's one patch behind, in one go." → `/upgrade-dep --all --max-class=patch`
- "Take the security advisories only." → `/upgrade-dep --security`
- After `/dependency-vuln-check` or `/audit --focus=security` names a package whose fix is a version bump.

## When NOT to use

- Porting a codebase from V1 to V2 — a different app, a parallel tree, per-feature parity → `/migrate`.
- "What is out of date / what is vulnerable?", no edits → `/dependency-vuln-check` (security pack) or `/audit --focus=security`.
- Rewriting YOUR code for its own sake, no version change → `/refactor` (one target) or `/optimize` (project-wide).
- Adopting a NEW dependency the project does not have → `/add-feature` (or `/scaffold-project` for a new app).
- Re-theming the UI after a design-system major lands → `/art-direct` / `/redesign` (ui-ux pack). This command lands the upgrade; it does not redesign on top of it.
- Applying the new version's idioms across code the upgrade did not touch → `/align` afterwards, once the idioms file names them.

## Args

- `<target>` — a package name (`tailwindcss`, `react`, `laravel/framework`, `django`, `flutter`, `com.squareup.retrofit2:retrofit`), a runtime (`node`, `php`, `python`, `dart`, `jdk`), or `--all` instead. Ecosystem is inferred from the manifest that declares it; `--ecosystem=<name>` forces it in a polyglot repo.
- `@<version>` (optional) — the exact target. Default: the current stable release, **never** a pre-release (`--allow-prerelease` to override).

Examples:

```
/upgrade-dep tailwindcss@4                    # framework major with an official codemod
/upgrade-dep react@19                         # framework major; drags the testing + types ecosystem
/upgrade-dep laravel/framework@12             # backend major; first-party packages move with it
/upgrade-dep django@5.2                       # backend major; check the deprecation shims first
/upgrade-dep node@22 --runtime                # runtime class — CI, image, engines, deploy target
/upgrade-dep flutter@3.38 --runtime           # mobile toolchain — both platforms must build
/upgrade-dep --all --max-class=minor          # batched sweep, stops before any major
/upgrade-dep --security                       # advisory-driven only, smallest version that fixes
/upgrade-dep tailwindcss@4 --dry-run          # classify + guide + oracle plan, write nothing
```

## Upgrade classes (the class decides the ceremony)

Classification happens first and is printed. Everything downstream — batching, commit shape, gates — is a function of it.

| Class | What it is | Batching | Gate |
|---|---|---|---|
| **patch** | `x.y.Z` within a minor; security backports | One commit for the whole batch | Existing suite green, before and after |
| **minor** | `x.Y.z`, additive by the ecosystem's own contract | One commit per package | Suite + build + deprecation-warning delta |
| **major-lib** | `X.y.z` on a library the app calls directly | One run, one package, never batched | Guide checklist closed item-by-item + oracle |
| **major-framework** | A major on the thing the app is *built inside* — the router, the ORM, the UI framework, the CSS engine | One run, alone; ecosystem fallout resolved in the same run | Oracle + config re-shape + first-party package sweep |
| **runtime** | The interpreter, SDK or toolchain itself | One run, alone | Every pin moves together (§ Runtime class) or HALT |

**Majors are never batched.** Two majors in one commit range means neither can be reverted, and the bisect that finds the regression has no useful granularity. `--all` stops at `--max-class` (default `minor`) and lists the majors as follow-up commands rather than taking them.

## Ecosystem matrix

The manifest pair, the probe, and the official codemod when one exists. Rows are how the run detects where it is; nothing here is assumed from the project's name.

| Ecosystem | Manifest + lock | Outdated / advisory probe | Official codemod, when the vendor ships one |
|---|---|---|---|
| Node (npm / pnpm / yarn / bun) | `package.json` + the lockfile in the tree | `<pm> outdated`, `<pm> audit` | `npx @tailwindcss/upgrade`, `npx @next/codemod`, `npx jscodeshift` packs, `npx types-react-codemod` |
| PHP (Composer) | `composer.json` + `composer.lock` | `composer outdated --direct`, `composer audit` | Rector rule sets (`rector process` against a `rector.php` that imports the release's set), framework-first-party upgrade packages |
| Python (pip / Poetry / uv) | `pyproject.toml` or `requirements*.txt` + the lock | `pip list --outdated`, `pip-audit` | `django-upgrade`, `pyupgrade`, `ruff --fix` for the deprecation classes each release documents |
| Dart / Flutter | `pubspec.yaml` + `pubspec.lock` | `dart pub outdated` | `dart fix --apply` (reads the SDK's own deprecation data) |
| Ruby | `Gemfile` + `Gemfile.lock` | `bundle outdated`, `bundle audit` (bundler-audit gem) | Rails `app:update` + `rubocop -a` for the release's cop set |
| Go | `go.mod` + `go.sum` | `go list -m -u all`, `govulncheck` | `go fix`, module-supplied `gofmt -r` rewrites |
| Rust | `Cargo.toml` + `Cargo.lock` | `cargo outdated`, `cargo audit` (both cargo sub-command installs) | `cargo fix --edition` |
| JVM (Gradle / Maven) | `build.gradle*` / `pom.xml` + the lock or version catalog | `gradle dependencyUpdates` (versions plugin), `mvn versions:display-dependency-updates` | OpenRewrite recipes (`rewrite-spring`, `rewrite-migrate-java`) |
| .NET | `*.csproj` + `packages.lock.json` | `dotnet list package --outdated --vulnerable` | `dotnet upgrade-assistant`, analyzer fixers |
| Swift / iOS | `Package.swift` / `Podfile` + the resolved lock | `swift package update --dry-run`, `pod outdated` | Xcode's own migrator for a Swift-language version bump |

**A probe the project has not installed is not a stall either** — several rows above are plugins or sub-command installs rather than built-ins, and where one is absent the run reads the manifest and the registry directly and says which probe it could not use.

**No codemod is not a blocker; it is a fact the report must state.** When the vendor ships none, the guide's breaking-change list becomes the checklist and every item is closed by hand with its `<file:line>` evidence. What is forbidden is inventing a codemod's existence, or running a third-party one as though it were the vendor's.

## Parity oracle by PROJECT_KIND

The oracle is chosen **before** anything is edited, and its baseline is captured on the pre-upgrade tree. An oracle established after the fact proves nothing — it can only confirm that the new state is self-consistent.

| PROJECT_KIND | Oracle floor (captured pre-upgrade, re-run post-upgrade) |
|---|---|
| `backend-*` / API | Suite green; the app **boots**; full route/endpoint inventory still registered (count + paths diffed); response-shape diff on the documented contract (OpenAPI / schema snapshot); ORM migration dry-run clean |
| `frontend-*` / `mobile-web` | Typecheck + production build; every route mounts without console errors; bundle-size delta recorded; visual diff on the key routes where a renderer is wired |
| `mobile-rn` / `mobile-native` (Flutter and the native toolchains alike) | **Both** platform targets build — an Android Gradle/AGP break and an iOS pod/Xcode break each show on one platform only; widget / instrumentation tests; a launch-and-first-screen smoke on a simulator |
| `library-*` / SDK | Exported public-API surface diffed symbol-by-symbol; at least one downstream consumer builds against the new version |
| `cli-*` | Golden-output tests over the documented commands; `--help` surface diffed |
| `data-*` / pipeline | One batch end-to-end with row-count + output-schema assertions against the pre-upgrade run |

**When the oracle floor does not exist**, the run halts and proposes the cheapest thing that would close the gap — usually a boot/build smoke check, occasionally three endpoint or screen assertions. It is installed and committed **before** the upgrade, on its own, so the baseline is recorded on the old version. Adding it afterwards is the failure this rule exists to prevent.

## Runtime class (the local-only upgrade)

A runtime upgrade that changes only the developer's machine is not an upgrade; it is a divergence. Every pin in this list that exists in the repo moves in the same run, and the report names each one:

- Version files — `.nvmrc`, `.tool-versions`, `.python-version`, `.ruby-version`, `.sdkmanrc`.
- Manifest constraints — `engines`, `"php"` in `composer.json`, `requires-python`, the Dart/Flutter SDK constraint, `<TargetFramework>`.
- Container images — every `FROM` in every Dockerfile, plus the compose files that pin a tag.
- CI — the version matrix in the workflow files.
- Deployment target — the buildpack, the serverless runtime identifier, the managed-platform setting, whatever the repo declares.

A pin that lives **outside** this repository (a cloud console setting, a base image built elsewhere) cannot be moved by this command. It is listed under `Risks:` by name, with what breaks if it stays behind — never silently omitted.

## What happens internally (silent)

1. **Pre-flight** — clean tree (or `--allow-dirty`), the manifest and lock are both tracked, the oracle's baseline command runs green *before* anything changes. A red baseline halts: an upgrade onto a broken tree cannot be told from an upgrade that broke it.
2. **Classify** — resolve target → ecosystem, current version, target version, direct vs transitive, and the class table above. Print it.
3. **Source the breaking changes** — fetch the vendor's guide / release notes / CHANGELOG for the exact span, and record the citation in the report. **Cite-or-halt**: no authoritative source for a major → HALT (`--no-guide` proceeds only with the absence stated in `Not validated:`). Spanning several majors is walked **one major at a time**, each with its own guide, its own commits and its own oracle run.
4. **Pin the oracle** — per the table above; capture the baseline; commit it first if it had to be created.
5. **Apply** — the vendor's codemod first, its output committed **verbatim and alone**. Then the manifest/lock bump. Then hand fixes, grouped one commit per breaking-change item.
6. **Sweep the residue** — the guide's breaking-change list becomes a checklist where every row ends `applied` / `not applicable — <why>` / `TODO`. Removed APIs are grepped for by name across the tree; a hit that survives the codemod is a row, not a shrug.
7. **Resolve the fallout** — peers, plugins, type packages and first-party ecosystem packages that this major drags with it. Each is either moved in this run (when the guide names it as required) or listed as a follow-up command — never auto-cascaded into another major.
8. **Verify** — re-run the oracle, diff against the baseline, record the numbers. Deprecation-warning count is recorded too: a build that is green but newly noisy is a finding, not a pass.
9. **Report** — the honesty block closes it (§ What you see).

## Commit shape

Four commit kinds, in this order, never mixed:

```
1  chore(deps): <name> <from> → <to>          manifest + lock only
2  chore(codemod): <tool> output, verbatim     no hand edits in this commit
3  fix(<area>): <breaking-change item>         one per guide item, with its citation
4  chore(config): re-shape <file> for <name> <to>
```

**Why the separation is load-bearing:** a codemod touching hundreds of files is reviewable only if nothing human is hiding in it, and `git revert` on the codemod commit is the fastest rollback an upgrade has. One mixed commit forfeits both. The report's `Revert:` line names the exact range.

## What you see (output)

```
Upgrade complete

Target:        tailwindcss  3.4.17 → 4.1.13      class: major-framework
Ecosystem:     node / pnpm                        guide: <vendor upgrade guide URL, cited>
Oracle:        build + typecheck + 34-route mount sweep + visual diff (12 key routes)

Codemod:       npx @tailwindcss/upgrade           142 files changed, committed verbatim
Hand fixes:    6 of the guide's 9 breaking-change items (3 not applicable — listed)
Config:        tailwind.config.js → @theme in src/assets/main.css (CSS-first)
Fallout:       postcss plugin moved with it; 2 plugins have no v4 build → follow-up commands below

Oracle result: build green · typecheck green · 34/34 routes mount · visual diff 12/12 within threshold
Deprecations:  build warnings 0 → 0
Bundle:        CSS 118KB → 71KB

Commits: 5    Diff: +604 / -1,155
Not validated:  the 2 plugins with no v4 build are stubbed out behind a flag — the pages that use them rendered, but their behaviour was not exercised
Risks:          @theme tokens are now global CSS variables — any inline style that hard-coded the old hex values is unchanged and will drift
Revert:         git revert <first-sha>..<last-sha>   (or just <codemod-sha> to undo the mechanical pass alone)

Actionable next steps:
  # the two plugins with no v4 build — decide replace vs drop
  /upgrade-dep <plugin-a> --dry-run
  # propagate the new token idioms into code the codemod never touched
  /align the design tokens
```

## What you DON'T see

Phase numbers, ledger states, ADR prompts — unless a genuine halt needs your decision. Just the classification, the evidence, and what is still open.

## Optional flags

- `--all` — every outdated **direct** dependency, batched by class, stopping at `--max-class`.
- `--max-class=<patch|minor|major-lib>` — ceiling for `--all` (default `minor`). Majors are listed, never taken in a batch.
- `--security` — advisory-driven only: the **smallest** version that clears each advisory, with the advisory ID cited per package.
- `--runtime` — treat the target as the runtime/toolchain and enforce § Runtime class.
- `--ecosystem=<name>` — force the ecosystem in a polyglot repo where two manifests declare a name.
- `--oracle=<command>` — supply the parity oracle explicitly when the project's is not detectable.
- `--no-codemod` — skip the vendor codemod and close every item by hand (use when the codemod is known-broken for this span; the reason is recorded).
- `--dry-run` — classify, fetch the guide, plan the oracle and print the checklist. Writes nothing.
- `--allow-prerelease` — permit an RC / beta / next tag. Off by default.
- `--relock` — regenerate the lockfile wholesale instead of the minimal edit. Off by default, because a full relock hides the upgrade's blast radius inside an unrelated diff.
- `--allow-dirty` — proceed with uncommitted changes.
- `--stay-on-major` — take the newest version **within** the current major; refuse to cross one.

## Halt conditions

- **No authoritative guide for a major** → HALT. `--no-guide` proceeds with the gap stated in the report; it is never assumed away.
- **No parity oracle and none can be cheaply built** → HALT with the proposal. An upgrade nothing can check is a change of unknown blast radius.
- **Baseline red before the upgrade** → HALT. Fix or `--allow-dirty` with the failure named; a broken starting point makes every later result unreadable.
- **The upgrade requires a runtime the repo's CI / image / deploy target does not declare** → HALT. Moving the library without its runtime pin is the local-only upgrade.
- **A peer or plugin has no release for the target version** → HALT that package's row: replace, drop, or pin with the reason. Never silently force-resolve a peer conflict.
- **The span crosses several majors** → the run walks them one at a time; it does not jump to the newest with one guide.
- **A public surface of a published library changes** → HALT for the deprecation decision (alias kept for ≥1 release vs clean break) before the commit.
- **Security advisory with no fixed version** → HALT; surface the backport / mitigation path instead of a version bump that does not exist.

## Hard rules (internal)

- **Never claim parity an oracle did not produce.** The oracle's name and result are printed; if it soft-failed or never ran, that is `Not validated:`, not a green line.
- **Never bump past the version whose guide was read.** The cited span and the applied span are the same span.
- **The codemod commit contains no human edits.** Mixing forfeits both the review and the cheapest revert.
- **The lockfile moves with the manifest, in the same commit, and is never regenerated wholesale** without `--relock` and a stated reason.
- **No pre-releases by default**, and a pinned version is a decision recorded in the report, not a silent `^` widening.
- **Majors are taken one at a time** — never two in a run, never batched under `--all`.
- **Runtime pins move together or not at all** (§ Runtime class); a pin outside the repo is named under `Risks:`.
- **Deprecation warnings are counted, before and after.** A green build that got noisier is the next major's failure arriving early.
- **Honesty clause is mandatory.** `Not validated:` / `Risks:` / `Revert:` close every run, per [`templates/tool-adapters/_orchestration-sync.md`](../templates/tool-adapters/_orchestration-sync.md) § Command boundary table's honesty clause — `Tests: green` without the negative space is the failure this repo names Trusted Summary.
- **Final report ends with paste-ready next steps** per [`templates/snippets/actionable-next-steps.md`](../templates/snippets/actionable-next-steps.md) — every halted row, skipped plugin and deferred major gets a runnable command, not a sentence.

## Failure modes

- **Guide fetched for the wrong span** (latest major's guide used for a two-major jump) → the residue sweep finds APIs the guide never mentioned; walk one major at a time.
- **Oracle captured after the edit** → every comparison is against the new state; the baseline must exist on the pre-upgrade tree, which is why it is committed first.
- **Codemod run on a dirty tree** → its output cannot be separated from your work; pre-flight refuses.
- **Peer conflict force-resolved** → the install succeeds and the runtime breaks; a peer with no compatible release is a halt row.
- **Runtime left behind** → green locally, red in CI or at deploy; § Runtime class is the checklist that prevents it.
- **Transitive major cascaded silently** → the diff contains two majors and the revert contains neither cleanly; fallout is listed, not auto-taken.
- **Green suite, dead feature** → the oracle covered less than it looked like it did. The oracle's *scope* is printed for exactly this reason: 34/34 routes mounting is not 34/34 routes working, and the report says which one it measured.

## Related

- `/migrate` — V1→V2 port across a parallel tree, per-feature parity. Different problem: that one moves *your* code between two apps, this one moves a *dependency* under one app.
- `/dependency-vuln-check` (security pack) · `/audit --focus=security` — find what is vulnerable or stale. They produce the list; this command closes one row of it.
- `/align` — after the upgrade, apply the new version's idioms to code the codemod never touched, once `_extracted-idioms.md` names them.
- `/optimize` — when the upgrade's point was performance, the measured before/after belongs there.
- `/learn-from-task` — promote the guide's surprises into the knowledge layer so the next major starts from them.
