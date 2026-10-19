# Precedents — Documentation (links, references, setup, env, API prose, samples, release notes, runbooks, ADRs, translations, hygiene)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 for every
candidate in a **documentation** class: a human doc that names something the repo no longer has
(a path, a symbol, a script, a flag, an env var, an endpoint, a k8s resource), describes something
that exists incorrectly (a version, a default, a package manager, a method), cannot be followed
(a broken link or anchor, a sample that does not compile, a setup step that fails), or whose
structure has rotted (the ADR graph, the changelog grammar, a stale or diverging translation, a nav
entry to nothing, a docs gate that cannot fail). The oracles that prove them are in
[`proof-oracles.md`](../proof-oracles.md) § Documentation (V430–V449). The detectors are
`doc-drift-scan` (§1–§14, docs against code and config, engine `doc-claims.py`),
`doc-structure-scan` (§1–§14, docs against docs) and `doc-sample-scan` (§1–§5, samples and spec
examples) (documentation pack). `quickstart-verify` executes the setup; `docstring-coverage` reads
the public API surface; `diagram-sync` checks diagrams.

**Owned elsewhere.** A neighbour that sees the same line lists it as corroboration, deduped by
`file:line`; without the owner's pack the row is tagged `<class> (owner pack <x> not installed)`
and listed, never graded as documentation would grade its own. The splits:
- **agent-facing knowledge** (`ai/**` except `ai/runbooks/**` and `ai/decisions/**`, `CLAUDE.md`,
  `AGENTS.md`, `.claude/**`) is the learning pack's `knowledge-ref-scan`; documentation owns human
  docs: README, CONTRIBUTING, `docs/**`, package READMEs, runbooks, ADR metadata, changelogs,
  translations (§ 28);
- accepted ADRs and convention docs **against code** are align `convention-oracle` AL-03/04;
  documentation grades only ADR **metadata** (status, supersession, index, number);
- `.env.example` against the env schema and `.env` is backend `env-diff`; documentation takes the
  **prose** docs against the same oracle;
- the committed OpenAPI spec against code or runtime is backend `http-contract-scan` §10;
  documentation takes prose endpoints (DA-1) and spec examples (DA-2);
- the changelog version against the released version is devops `release-integrity-scan` RL-2;
  documentation takes the breaking set against the notes (DH-1) and the grammar (DH-2);
- an alert with no `runbook_url` is observability `alert-rule-lint`; documentation takes the URL
  that resolves to nothing (DK-3);
- UI string catalogs are frontend `i18n-scan`; TODO debt in code is code-quality `debt-ledger`;
  Refract's own `ai/` setup artifacts are `/setup-project-health`.

"Is the code correct" belongs to the code's owner; "does the doc tell the reader the truth, and can
the reader follow it" is documentation's.

Each entry names when a pattern that *looks* like a defect is not one, and the evidence that flips
it back. A match makes the candidate **Hardening**, or Refuted where the entry says so, unless the
flip evidence is shown with a `file:line`, a config value or a recorded oracle run. Numbers are
stable: detectors and `doc-claims.py` skip rows cite `precedents/documentation.md § <n>`.

Index: the claim and the gates · scope § 1–2, 27–28 · resolution § 3–10, 19–20, 24, 31 · external
links § 15 · setup and samples § 14, 21, 23 · direction § 16–17, 25 · structure § 11–13, 18, 22,
26, 29–30 · tool traps § 32–34 · rationalizations.

## The claim, restated

§ 1 of the protocol takes one shape here, and it names **both ends**: the doc line and the oracle
line, or the oracle's silence after a written search. A row with one end is not a candidate.

> **[The doc at file:line]**, read by **[a reader on the primary surface: README, quickstart,
> CONTRIBUTING, a runbook, a published API page — or a secondary one]**, says **[the claim:
> path, symbol, script, flag, version, env default, endpoint, resource, link, status]**, while
> **[the oracle at file:line: the tree, a manifest, the env schema, the spec or router, the deploy
> manifests, git history, the target doc]** says **[the other value, or nothing after the search]**,
> so the reader **[hits an error, follows a dead link, runs an old command, trusts a wrong
> default]**, proven by **[V430–V449]**.

**Direction is decided at fix time, not here** (§ 16). Of the outdated code references that real
projects fixed, about half were fixed by restoring the code (Tan, Wagner & Treude, EMSE 2024). The
detector reports the pair; the fix decides which end moves.

**The proof rule.** A static two-ended fact (DL, DR, DS-2/3, DE, DA-1, DK, DX, DI, DF) passes gate 6
with both ends cited and the recheck (`doc-claims.py --recheck=<id>`) still failing. An execution
class (DS-1 setup, DC-1 compile, DC-2 doctest) passes only when the project's own toolchain ran in
a scratch copy and failed. A gate class (DL-4, DC-4) passes only with a mutation proof (§ 29).

## Reading the seven gates for documentation

| Gate | Documentation |
|---|---|
| 1 Reachability | a reader reaches the doc: it is in scope (§ 1, § 2, § 12, § 27, § 28), served or linked from the README, the site nav or a code string |
| 2 Trigger | the reader follows the claim: runs the command, opens the link, copies the sample, sets the variable. A claim in prose that no step depends on is lower severity, never dropped |
| 3 Version | the tool and runtime versions in the lockfile and pins: the slugger of the renderer in use (§ 10), the package manager the lockfile names, the oasdiff or TypeDoc version a gate runs |
| 4 Existing control | the docs gate already catches the class and is not silenced (§ 29), the doc is generated (§ 17), the path is produced by a documented command (§ 5) |
| 5 Impact | a reader is blocked or misled on a primary surface; a 2 am runbook step fails. Style alone fails here (§ 22) |
| 6 Proof | the two-ended static fact plus the failing recheck; an execution lane's exit and stderr; a mutation proof for a gate |
| 7 Environment | the deploy the doc describes: in-repo manifests versus live infra (§ 19), a versioned doc set (§ 12), a deploy profile the doc names |

## Scope

1. **Dated records are history.** Audit reports, run logs, postmortems, incident notes, meeting
   notes, `ai/audits/`, `ai/runs/`, `ai/dynamic/`, the bodies of past CHANGELOG entries and the
   bodies of ADRs. A reference in them is not drift: on one real monorepo, 3,250 of the 3,446
   misses a naive scan printed sat in dated audits. In an ADR or a changelog only doc-to-doc links
   are checked (navigation still has to work). *Flip:* a primary doc links the record as current
   guidance ("follow the steps in …"), or the ADR's status metadata is wrong (DX).
2. **Tool and agent configuration directories** (`.claude/`, `.opencode/`, `.cursor/`,
   `.windsurf/`, `.github/copilot-*`, `.github/instructions/`) are installed tooling text, not
   project docs. *Flip:* the README tells readers to follow them.
3. **Paths relative to a package root.** `apps/api/README.md` saying `src/main.ts` resolves against
   the doc's directory, each package root, then a unique suffix, before MISS; an ambiguous match is
   CHECK, and a name that ends more than five paths (`api/`, `i18n/index.ts`) is a per-module
   layout name, not a reference [V: 85 recovered on one monorepo]. *Flip:* no candidate under any
   root.
4. **Gitignored, local-only or generated paths** (`.env`, `dist/`, `build/`, coverage, screenshot
   dirs) are not DEAD: `git check-ignore`, with the directory form tried too. *Flip:* the doc says
   the path is committed, or the command that generates it no longer exists.
5. **Paths a documented command creates** ("written by …", "the command produces …") are
   conditional: CHECK, never MISS. *Flip:* the producing command is gone.
6. **Illustrative placeholders.** `example.com` / `.test` / `.example` / `.invalid` / `.localhost`
   (RFC 2606, RFC 6761), TEST-NET addresses (RFC 5737), `<your-token>`, `/x/{id}`, `...`, `pseudo`
   fences, template files (`_template.md`), and how-to lines ("Building `POST /products` end to end.
   Adapt the nouns"). *Flip:* the placeholder sits in a step that must run as written.
7. **Routes excluded from the spec by design** (`/metrics`, health, OAuth callbacks marked
   `@ApiExcludeEndpoint`): resolve against the router before MISS. *Flip:* the router has no such
   route either.
8. **Env vars set or read by others.** Platform-set (`CI`, `GITHUB_*`, `RUNNER_*`, `PORT`,
   `NODE_ENV`, `HOSTNAME`) and read by SDKs and tools (`AWS_*`, `ANTHROPIC_*`, `KUBECONFIG`): not
   DEAD. *Flip:* the doc says the **app** reads it, and the app's schema does not.
9. **Not an env var, not a project symbol.** CAPS constants, error codes, enum members and SQL
   keywords are not env claims: an env claim needs an env context (an env table, `.env`, `export`,
   `X=` in a fence) [V: 274 tokens → about 4]. Framework and platform vocabulary (`Math.ceil()`,
   `CreateContainerConfigError`, `HttpOnly`, `useMemo`) is not a project symbol: DR-2 reports a name
   only when it is project-shaped (a `…Service`, `…Processor`, `…Input` type) or its receiver is the
   project's. *Flip:* the doc says the project defines it.
10. **Renderer-specific anchors.** GitHub slugs (lowercase, punctuation dropped, Unicode letters
    kept, duplicates `-1`, `-2`), MkDocs `toc` (ASCII unless `pymdownx.slugs`, duplicates `_1`),
    Docusaurus `{#id}`, Sphinx labels, `<a name>` / `id=`, `#L42` line anchors and `#top`. Resolve
    with the renderer in use. *Flip:* no renderer the project uses produces it.
11. **Translations lagging by policy.** A translated page behind its source that carries an
    outdated banner, or a repo that declares a lag policy, is not a finding (Kubernetes pins a
    target release per locale; MDN froze unmaintained locales). *Flip:* the translation carries a
    different **command, code or link** (DI-3), or translates a page deleted upstream.
12. **Versioned docs** (`versioned_docs/version-x/`, `docs/v1/`) describe their release, not HEAD.
    *Flip:* the versioned set is the one served by default (no `latest`).
13. **Superseded and retired ADRs** name removed things; that is history (Nygard, MADR). *Flip:*
    the status says Accepted.
14. **Non-compiling fences on purpose.** Excerpts with `...` / `// ...`, `text`, `diff`, `console`
    transcripts, rustdoc `ignore` / `no_run` / `compile_fail`, Go examples without `// Output:`
    (compile-only), pydantic `test="skip <reason>"`, and statement fragments with no import. *Flip:*
    the fence is a complete program in a "copy and run" step, or the project's harness marks it
    runnable.
15. **External link status codes.** 429 rate limits, LinkedIn 999, 403 auth walls and bot blocks
    are not dead links; Django gates offline checks and runs `linkcheck` separately. *Flip:* 404,
    410 or a DNS failure, reproduced twice with a token.
16. **The doc is the contract.** Spec-first OpenAPI, a published API reference, the documented
    flags of a versioned public CLI, an ADR-backed promise. A mismatch may be a **code regression**:
    route it to `/fix-bug` or `/backend-fix`, never edit the doc to bless it.
17. **Generated docs** (a changelog from release-please, changesets, git-cliff or semantic-release;
    a reference from TypeDoc or OpenAPI; a CLI reference from `--help`) are fixed at the source
    (commit, config, annotation) and regenerated, never hand-edited. An unreleased breaking commit
    under a generator is the generator's to announce at release.
18. **Per-package versioning in monorepos.** Independent versions, tags (`pkg@1.2.3`) and changelogs
    per package are not a mismatch (devops precedent § 17).
19. **Third-party or live-infra commands and resources** (`kubectl`, cloud CLIs, consoles; a Service
    a third-party Helm chart creates; a Secret created out of band) are `UNVERIFIED (live-infra)`
    or skipped, never DEAD, when no in-repo manifest could name them. A flag on a third-party CLI is
    § 19 too. *Flip:* the repo's own manifests or Helm values name the resource and the doc's name
    differs.
20. **Generator provenance banners** ("Auto-populated by `scripts/X.sh`") name the generator's own
    repo [V: 79 hits from one banner]. *Flip:* the banner tells the reader to run it.
21. **Setup steps needing secrets, paid accounts or hardware** are documented prerequisites, not
    failures: `PREREQUISITE (secret)`.
22. **Style is not a gate.** MD040, heading increments, line length and prose style are NIT unless
    the project configures and enforces the linter [V: 1,309 unlabelled fences on one monorepo].
23. **Application code docstrings.** An unpublished app's internal symbols are advisory (LOW).
    *Flip:* the package is published or consumed across a workspace boundary.
24. **"It's in the manual."** Before UNDOCUMENTED (DE-2), search every doc surface, `.env` example
    comments, error messages, `--help` and schema descriptions (the SPEX rebuttal). *Flip:* none
    mentions it.
25. **A changelog omission is retro-fixable.** Keep a Changelog endorses adding an omitted breaking
    change to an old entry; § 1 does not protect an omission.
26. **The ADR id parser.** A date (`superseded 2026-09-23`) is not an ADR id; a supersession target
    must be a link or an `ADR-n` id that matches a file [V].
27. **Test data and fixtures are not docs.** Markdown under `test/`, `tests/`, `fixtures/`,
    `testdata/`, `__snapshots__/` is input to a test. *Flip:* the README links it as a guide.
28. **Agent-facing knowledge routes to learning.** `ai/**` outside `ai/runbooks/` and
    `ai/decisions/`, and `CLAUDE.md` / `AGENTS.md`, are read by agents; the learning pack's
    `knowledge-ref-scan` owns their dead references. The engine counts them as `-> learning` and
    never grades them. Runbooks (humans follow them at 2 am) and ADR metadata stay here.
29. **A gate is proven by failing, not by existing.** A docs CI step proves nothing until a planted
    broken link and a planted broken anchor in a scratch copy turn it red on the PR path. A gate
    whose config silences it (§ 32) is DL-4 even when the job is green.
30. **Partial supersession keeps the target Accepted.** "Supersedes: the chrome clause of [0016]",
    "in part", "amends" leave the older ADR in force; only a whole supersession requires the target
    to read Superseded. *Flip:* the newer ADR says it replaces the whole decision.
31. **A script that lives in one package.** `pnpm db:migrate` in `apps/api/README.md` with the
    script defined only in `apps/api/package.json` works from that directory: CHECK, not MISS.
    *Flip:* the doc runs it from the root with no `--filter` and no `cd`.

## Tool traps

32. **Exit codes are per tool.** lychee: 0 ok, **2 = broken links**, 1 = runtime or config error, 3
    = config-file error, the reverse of markdownlint-cli2, rumdl, Vale, textlint and Schemathesis
    (2 = the tool broke). `kacl-cli verify` returns the **error count** (mod 256 wraps). A `ck`
    wrapper maps each tool, never `!= 0` or `== 2` blanket. Silent passes: `remark` without
    `--frail`; `oasdiff breaking` without `--fail-on ERR`; `openapi-diff` without
    `--fail-on-incompatible`; TypeDoc's `notDocumented` is off and warnings exit 0 without
    `treatValidationWarningsAsErrors`; Docusaurus defaults `onBrokenAnchors` and
    `onBrokenMarkdownLinks` to `warn`; MkDocs leaves `validation.links.anchors` at `info`;
    mdbook-linkcheck's default `warning-policy` is `warn`; Spectral with no ruleset lints nothing;
    `rumdl fmt` exits 0 with violations left (use `check`).
33. **NOT-RUN is never PASS.** pytest exit 5 means nothing was collected; `--doctest-glob='*.md'`
    runs only `>>>` prompts and passes plain ```` ```python ```` fences as 0 tests; rustdoc lints are
    warnings; the `@eslint/markdown` processor turns off `no-undef`; a lane whose tool is absent is
    `blocked (<tool> not installed)`.
34. **Telemetry and archived tools.** Redocly CLI sends usage data unless `REDOCLY_TELEMETRY=off`;
    the AsyncAPI CLI reports to New Relic unless `CI=true`; Runme's telemetry is unverified, so it
    stays out of the lanes. Optic (archived 2026-01), Dredd (archived 2024), darglint (archived
    2022), eslint-plugin-jsdoc `check-examples` (dead on ESLint ≥ 8) and the Structurizr CLI / Lite
    (EOL) are never recommended; their replacements are oasdiff, Schemathesis, pydoclint and
    `structurizr validate`.

## Rationalizations

**Wrongly flagging a defect:**
- "This doc names a deleted file." Is it a dated record (§ 1), a package-root path (§ 3), a
  gitignored output (§ 4), or agent-facing knowledge (§ 28)?
- "The flag does not exist." On a third-party CLI (§ 19)?
- "The doc must be fixed." Is the doc the contract (§ 16), or generated (§ 17)?
- "The translation is behind." Is there a banner or a lag policy (§ 11), and does it carry a
  different command (DI-3)?
- "2,000 misses." That is a scope failure (§ 1, § 2, § 28), not 2,000 findings.

**Wrongly clearing a defect:**
- "The docs job is green." Can it fail (§ 29, § 32)?
- "It is only a runbook." A runbook step that fails at 2 am is HIGH.
- "The README is old anyway." The README is the primary surface.
- "Nobody copies the samples." The registry page renders the README.

---

Sources: the documentation research catalog (2026-10-19) § 1–5 and its two notes (tools; taxonomy,
precedents and LLM evidence); the batch-7 documentation eval (2026-10-19) § 3. Prevalence and fix
direction from Tan, Wagner & Treude (EMSE 2024); tutorial executability from Docable (FSE 2020);
link decay from Hata et al. (ICSE 2019); ADR lifecycles from Nygard (2011) and MADR 4.0.0
(2024-09-17); Keep a Changelog 1.1.0; reserved names from RFC 2606, 6761 and 5737. Tool behaviour
(lychee 0.24.2, markdownlint-cli2 0.23.3, rumdl 0.3.0, remark-validate-links 13, MkDocs 1.6,
Docusaurus 3.10.2, Sphinx 9.1, mdbook-linkcheck 0.7.7, oasdiff 1.34.0, openapi-diff 2.1.7, Spectral
6.17.0, Redocly CLI 2.64.1, AsyncAPI CLI 6.2.1, python-kacl 0.7.7, TypeDoc 0.28.20, pytest 9,
pydoclint 0.11.1) is as fetched on 2026-10-19 and recorded in the research notes. Real-repo rows
were measured read-only on one NestJS + React monorepo on 2026-10-19. Paraphrased; no text is
reproduced beyond short quoted identifiers.
