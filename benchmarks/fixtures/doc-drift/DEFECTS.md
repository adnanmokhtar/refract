# Seeded defects — `doc-drift`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the agent scans. If you stage the
fixture by hand, delete this file from the copy first — an agent that reads it will score 100% and the number will mean
nothing.

Fixture shape: `Tallyhook` — a pnpm workspace for an invoicing API (NestJS-shaped API with a committed OpenAPI spec and a zod env schema, a published TypeScript SDK, a Python money library with doctests) and its whole doc set: an MkDocs guide in English and Arabic, reference pages, ten ADR files, four runbooks, alert rules, a changelog and a release history; 76 documentation seeds (two per owned class), 22 decoys.

Invocation: /doc-refresh --audit --whole-repo
Stage with: --git --history

Staging is one command. `bash benchmarks/run.sh --fixture=doc-drift --workdir=<dir>` stages the tree (minus this key)
with one commit and, because the key says `--history`, then runs the copy's `.refract-fixture/stage-history.sh`, which
replaces that commit with a fixed 14-commit history (author `bench`, fixed dates, tags `v1.4.0` and `v1.5.0`) built from
`.refract-fixture/history/`, and deletes `.refract-fixture/`, so the final tree equals the staged copy minus that
directory. The audit reads history in three places: the breaking-change lane (`doc-drift-scan` §12 needs release tags),
the translation-staleness lane (`doc-structure-scan` §11 compares the last commit time of a source page and of its
translation when no source-commit marker exists) and the rename lookup behind a dead path (`renamed -> …`,
`deleted in …`). A copy staged by hand (or with the `--history` word removed from the key) is still valid but history-blind: DH-1 prints
`N/A (no release tags)` and DI-2 compares one commit with itself (the engine then prints
`DI-2 checked (6 claims -> 0 candidates)`, which reads as clean: engine gap 1 below), so DOC-DH1-a/b and DOC-DI2-a/b
cannot be found (expected, and they cost those four seeds), the decoy DOC-DECOY-13 is moot, and the dead-path rows lose
their `renamed ->` detail. Record which way the copy was staged next to the result.

Eval source: Track A batch 7, `eval-batch7-documentation.md` § 2 (the 38 owned classes and their one owner), § 3.1
(one engine, two oracles), § 4.10 (fixture design). Classes are the research catalog's `D*` ids; precedents are
`templates/snippets/precedents/documentation.md` § n; proofs are `proof-oracles.md` § Documentation (V430–V449); the
engine is `templates/packs/documentation/skills/doc-drift-scan/scripts/doc-claims.py`. Roots:
- `apps/api` — NestJS-shaped TypeScript (decorators as text, `setGlobalPrefix('v1')`, `@ApiExcludeEndpoint` on
  `/metrics` and `/health`), `src/config/env.schema.ts` (zod: required keys, `.default()`, `z.enum`), the `tallyhook`
  CLI (`bin`, commander), `openapi.json` with examples, `.env.example`, a Dockerfile;
- `packages/sdk` — `@tallyhook/sdk`, published (`publishConfig.access: public`): exports, TSDoc with `{@link}`, one
  `@deprecated` method, `typedoc.json`, a README with TS fences;
- `packages/py-money` — Python with doctests in the README and docstrings; `pyproject.toml` with
  `requires-python >=3.12`, ruff `D` and pydoclint, and a pytest doctest harness;
- `docs/` — `mkdocs.yml` at the root with `docs_dir: docs/guide`, mkdocs-static-i18n (`en` default, `ar`,
  `fallback_to_default: true`), not strict, a `nav:`; `docs/guide/` pages with Arabic translations under
  `docs/guide/ar/`; reference pages `docs/api.md`, `docs/config.md`, `docs/architecture.md` (mermaid) and others read on
  the code host; `docs/adr/` (0001–0008, a second 0008, 0010, an index and a template); `docs/runbooks/`; `docs/v1/`;
- `deploy/k8s/` (Namespace, Deployments, Service, ConfigMap, CronJob), `deploy/alerts/rules.yml` with `runbook_url`,
  `docker-compose.yml`, `Makefile`, `scripts/`, `.github/workflows/` (CI and a docs job);
- decoy-only areas: `ai/audits/` (a dated report), `.claude/commands/` (tool configuration).

Departures from the eval, stated so a reader can audit them:
- **The ADR set is 0001–0008 plus a second 0008 and 0010**, not 0001–0007: DX-3 needs a colliding number and a title
  that contradicts its file, and DX-1's "0005 supersedes 0009" needs 0009 absent.
- **The history is the fixture's own script, which `run.sh` calls.** The eval asks `run.sh` to build the history from
  `history/commits.tsv`; `run.sh` gained a generic `Stage with: --history` flag instead, which runs the key's
  `.refract-fixture/stage-history.sh` on the staged copy (so the history format stays the fixture's business). No commit SHA appears in any fixture file: DI-2 uses the commit-time path (no
  source-commit marker), which the engine reports as CHECK.
- **The translated-page decoy carries a per-page banner and no repo-wide lag policy.** The eval pairs the banner with a
  declared policy; a declared policy anywhere silences every DI-1 row (the engine reads it repo-wide), which would erase
  DOC-DI1-a/b.
- **DL-3 seeds use the reserved `.invalid` TLD**, as the eval says. Precedents § 6 lists `.invalid` among illustrative
  hosts; these two sit in steps the reader is told to follow (§ 6's flip), standing in for a vendor domain that went away.
  Offline the engine only counts them: bucket `Unconfirmed — NETWORK=1 settles`.
- **Several seeds print a second engine row for the same root cause**, and one finding covers both: DOC-DL4-a (the CI
  `mkdocs build` line and `mkdocs.yml:0 strict`), DOC-DI3-a (DI-3 plus a DR-3 MISS on the Arabic `pnpm dev:all`),
  DOC-DI3-b (DI-3 plus a DL-1 MISS on the Arabic link).
- **DS-1, DD-1/2/3 and DF-3 cite the § numbers this batch defines for them** (`quickstart-verify` §1 missing prerequisite
  and §3 wrong order; `docstring-coverage` §1–§3); the shipped `quickstart-verify`, `docstring-coverage` and
  `diagram-sync` files have no § table yet.

Ownership and scoring. One run, `/doc-refresh --audit --whole-repo`, one results row: every seed is documentation-owned
(`owner: documentation`); no routed rows. `bucket:` is the row's expected disposition under `/doc-refresh` A3:
`report-with-fix` (both ends cited, the recheck fails, the fix is a docs edit), `report-flagged` (one link a person
decides: a translation policy, a whole or partial supersession, a publication question, a stub's contract),
`Unconfirmed (static) — container lane settles` (DS-1: the static pre-pass sees it, the container run proves it),
`Unconfirmed — <probe>` (DL-3 offline; DC-1 with no `node_modules`). A decoy's `class:` is the class a false report would
claim; `precedent:` is the entry that clears it.

Secrets. None. Hosts are `example.com` subdomains or the reserved `.invalid` TLD; the API key and the webhook secrets are
read from the environment; the local Postgres uses `trust` auth in Docker Compose.

Measured 2026-10-19 with `doc-claims 1.0` (`python3 -I -B`, Python 3.8.20) and git 2.50.1, on a copy staged by
`run.sh --workdir=<scratch>` and then `stage-history.sh` (14 commits, tags `v1.4.0` and `v1.5.0`, HEAD `b5b432b` on two
independent runs; no `DEFECTS.md` and no `.refract-fixture/` left in the copy), every output in a scratch `--out`.
Ledger: 42 docs in scope (doc 31, adr 10, changelog 1; 4 runbooks), skipped `-> learning` 1 (`ai/audits/`), § 2 1
(`.claude/`), § 12 1 (`docs/v1/`), § 6 1 (the ADR template); renderer `mkdocs (docs/guide)`; 3 package roots; no lane
blocked. **Candidates (exit 1): 61 rows**, two per engine class (DA-1, DA-2, DC-3, DE-1, DE-2, DE-3, DF-1, DF-2, DH-1,
DH-2, DI-1, DI-2, DI-3, DK-1, DK-2, DK-3, DL-2, DR-1, DR-2, DR-4, DR-5, DS-2, DS-3, DX-1, DX-2, DX-3) and three for DL-1,
DL-4 and DR-3, the third being the documented twin of DOC-DI3-b, DOC-DL4-a and DOC-DI3-a. **Engine-detectable seeds
printed: 58 of 58** (29 classes × 2); unseeded rows: 0. The other 18 seeds are outside the engine by design: DL-3
(offline, 10 external links counted), DS-1, DC-1, DC-2, DC-4, DD-1/2/3 and DF-3. **`--all`: 263 rows** (178 `ok`, 24 `skip`
with their precedent); decoys printed as candidates: **0 of 22** — 02 `skip(§10)`, 06 `skip(§4)`, 07 and 08 `skip(§8)`, 13
`skip(§11)`, 16 `skip(§7)`, 17 `skip(§19)`, 20 `skip(§20)`, 03/04/05 `ok`, 01 counted as external, 12/21/22 scope skips in
the ledger, the rest no row (ADR and changelog bodies, fences, no env context, a live-infra name). **`--fences`: 32
fences** — shell 21, candidate 3 (ts: the two SDK README samples and the embedded retry snippet), doctest 2 (pycon),
excerpt 2 (the SDK guide and its translation), not-code 2 (mermaid, pseudo), config 1 (json). The DC-2 seeds were run
with Python 3.13 `doctest` in the scratch copy: the README prints `Expected: 101 / Got: 100`, `format.py` raises
`NameError: name 'format_minor' is not defined`, `convert.py` passes 2/2 and the package's unit assertions hold. DC-1 was
not compiled (no TypeScript ≥ 5 on the machine; no install). On the one-commit copy (no `stage-history.sh`): 57 rows,
54 of 58 — DH-1 `N/A (no release tags)`, DI-2 `history-blind (6 pair(s): one commit …)`, and the DL-1 and DR-1 rows lose their
`renamed ->` / `deleted in` detail. Score check: a findings file made only of the 61 engine rows (`path:line`, claim,
detail) scores **58/76, 0/22 decoys flagged**, the 3 twin rows UNMATCHED; a deliberately false report on each decoy pins
**22/22**.

Engine gaps found by the fixture build, all six **fixed in the batch-7 integration pass (2026-10-19)**, each with a
failing-first self-test case (`doc-claims.py --self-test` 46 → 53 checks), re-measured above (61 rows, 58 of 58; on the
history copy DI-2 now also says `history-blind on 2 pair(s)` for the two pairs committed together): (1) **DI-2 on a history that cannot tell the pages apart** (one
commit, or every pair committed together) counts every pair `ok` and prints `checked (k claims -> 0 candidates)`; the
honest line is `history-blind`. (2) **The DH-1 "announced" test is a substring vote**: a breaking commit counts as
announced when half its subject words of four or more letters appear anywhere in the section, so one unrelated bullet
("order pages load faster with fewer query params") clears `drop the page param` (measured on a scratch copy). (3)
**DE-2 rows carry no `file:line`** (doc empty, line 0); the schema location is only in the detail. (4) **DI-3's claim is
the first line of the differing block** (`pnpm install`), not the line that differs, at line 0. (5) **The `surface`
column marks `docs/api.md`, `docs/config.md` and every guide page but the setup page `secondary`**, while the skills' severity rule counts
published API and setup docs as primary. (6) A DL-1 MISS with no rename or delete in history prints a dangling `; ` in
its detail. Fixed: (1) prints `history-blind`; (2) one line must carry at least half the subject words as whole words and a
breaking or removal signal; (3) DE-2 sits at the schema line, surface primary; (4) DI-3 names the line that differs and
its line number; (5) API, SDK, reference and configuration docs and OpenAPI files are primary; (6) no separator without a
note. The full row set is pinned by `tests/doc-claims/engine.expect`, which `tests/doc-claims/run.sh` (run by
`scripts/test-validators.sh`) compares on every run.

Line numbers are exact against the files in this directory and are re-checked by `benchmarks/run.sh --verify`, which also
fails if a decoy sits within 12 lines of a defect in the same file. Every line was computed from its anchor
(`~/.claude/refract-program/build-notes/doc-drift/gen.py`).
## Summary

| id | file:line | severity | command | class | detector | bucket |
|----|-----------|----------|---------|-------|----------|--------|
| DOC-DL1-a | `README.md:37` | medium | `/doc-refresh` | DL-1 | doc-structure-scan §1 | report-with-fix |
| DOC-DL1-b | `CONTRIBUTING.md:31` | medium | `/doc-refresh` | DL-1 | doc-structure-scan §1 | report-with-fix |
| DOC-DL2-a | `README.md:21` | medium | `/doc-refresh` | DL-2 | doc-structure-scan §2 | report-with-fix |
| DOC-DL2-b | `docs/runbooks/restore-db.md:20` | medium | `/doc-refresh` | DL-2 | doc-structure-scan §2 | report-with-fix |
| DOC-DL3-a | `docs/guide/webhooks.md:18` | low | `/doc-refresh` | DL-3 | doc-structure-scan §3 | Unconfirmed — NETWORK=1 settles |
| DOC-DL3-b | `packages/sdk/README.md:44` | low | `/doc-refresh` | DL-3 | doc-structure-scan §3 | Unconfirmed — NETWORK=1 settles |
| DOC-DL4-a | `.github/workflows/docs.yml:18` | medium | `/doc-refresh` | DL-4 | doc-structure-scan §4 | report-with-fix |
| DOC-DL4-b | `.github/workflows/docs.yml:23` | medium | `/doc-refresh` | DL-4 | doc-structure-scan §4 | report-with-fix |
| DOC-DK3-a | `deploy/alerts/rules.yml:11` | high | `/doc-refresh` | DK-3 | doc-structure-scan §5 | report-with-fix |
| DOC-DK3-b | `apps/api/src/common/errors.ts:5` | medium | `/doc-refresh` | DK-3 | doc-structure-scan §5 | report-with-fix |
| DOC-DX1-a | `docs/adr/0006-redis-rate-limit.md:5` | medium | `/doc-refresh` | DX-1 | doc-structure-scan §6 | report-flagged |
| DOC-DX1-b | `docs/adr/0005-cursor-pagination.md:7` | medium | `/doc-refresh` | DX-1 | doc-structure-scan §6 | report-flagged |
| DOC-DX2-a | `docs/adr/0007-money-as-integers.md:5` | low | `/doc-refresh` | DX-2 | doc-structure-scan §7 | report-with-fix |
| DOC-DX2-b | `docs/adr/README.md:11` | low | `/doc-refresh` | DX-2 | doc-structure-scan §7 | report-with-fix |
| DOC-DX3-a | `docs/adr/0008-sdk-codegen.md:1` | low | `/doc-refresh` | DX-3 | doc-structure-scan §8 | report-with-fix |
| DOC-DX3-b | `docs/adr/0010-tenant-scoped-keys.md:1` | low | `/doc-refresh` | DX-3 | doc-structure-scan §8 | report-with-fix |
| DOC-DH2-a | `CHANGELOG.md:49` | low | `/doc-refresh` | DH-2 | doc-structure-scan §9 | report-with-fix |
| DOC-DH2-b | `CHANGELOG.md:55` | low | `/doc-refresh` | DH-2 | doc-structure-scan §9 | report-with-fix |
| DOC-DI1-a | `docs/guide/webhooks.md:1` | low | `/doc-refresh` | DI-1 | doc-structure-scan §10 | report-flagged |
| DOC-DI1-b | `docs/guide/reports.md:1` | low | `/doc-refresh` | DI-1 | doc-structure-scan §10 | report-flagged |
| DOC-DI2-a | `docs/guide/ar/billing.md:1` | low | `/doc-refresh` | DI-2 | doc-structure-scan §11 | report-flagged |
| DOC-DI2-b | `docs/guide/ar/sdk.md:1` | low | `/doc-refresh` | DI-2 | doc-structure-scan §11 | report-flagged |
| DOC-DI3-a | `docs/guide/ar/setup.md:17` | medium | `/doc-refresh` | DI-3 | doc-structure-scan §12 | report-with-fix |
| DOC-DI3-b | `docs/guide/ar/index.md:6` | medium | `/doc-refresh` | DI-3 | doc-structure-scan §12 | report-with-fix |
| DOC-DF1-a | `docs/guide/billing.md:18` | low | `/doc-refresh` | DF-1 | doc-structure-scan §13 | report-with-fix |
| DOC-DF1-b | `docs/operations.md:21` | low | `/doc-refresh` | DF-1 | doc-structure-scan §13 | report-with-fix |
| DOC-DF2-a | `mkdocs.yml:33` | low | `/doc-refresh` | DF-2 | doc-structure-scan §14 | report-with-fix |
| DOC-DF2-b | `docs/guide/legacy-sso.md:1` | low | `/doc-refresh` | DF-2 | doc-structure-scan §14 | report-flagged |
| DOC-DR1-a | `README.md:32` | medium | `/doc-refresh` | DR-1 | doc-drift-scan §1 | report-with-fix |
| DOC-DR1-b | `packages/sdk/README.md:33` | medium | `/doc-refresh` | DR-1 | doc-drift-scan §1 | report-with-fix |
| DOC-DR2-a | `docs/architecture.md:19` | low | `/doc-refresh` | DR-2 | doc-drift-scan §2 | report-with-fix |
| DOC-DR2-b | `apps/api/README.md:38` | medium | `/doc-refresh` | DR-2 | doc-drift-scan §2 | report-with-fix |
| DOC-DR3-a | `README.md:18` | high | `/doc-refresh` | DR-3 | doc-drift-scan §3 | report-with-fix |
| DOC-DR3-b | `CONTRIBUTING.md:14` | high | `/doc-refresh` | DR-3 | doc-drift-scan §3 | report-with-fix |
| DOC-DR4-a | `apps/api/README.md:30` | medium | `/doc-refresh` | DR-4 | doc-drift-scan §4 | report-with-fix |
| DOC-DR4-b | `docs/guide/reports.md:11` | medium | `/doc-refresh` | DR-4 | doc-drift-scan §4 | report-with-fix |
| DOC-DR5-a | `packages/sdk/README.md:29` | medium | `/doc-refresh` | DR-5 | doc-drift-scan §5 | report-with-fix |
| DOC-DR5-b | `docs/api.md:24` | medium | `/doc-refresh` | DR-5 | doc-drift-scan §5 | report-with-fix |
| DOC-DS2-a | `README.md:8` | medium | `/doc-refresh` | DS-2 | doc-drift-scan §6 | report-with-fix |
| DOC-DS2-b | `CONTRIBUTING.md:8` | medium | `/doc-refresh` | DS-2 | doc-drift-scan §6 | report-with-fix |
| DOC-DS3-a | `CONTRIBUTING.md:11` | medium | `/doc-refresh` | DS-3 | doc-drift-scan §7 | report-with-fix |
| DOC-DS3-b | `apps/api/README.md:21` | medium | `/doc-refresh` | DS-3 | doc-drift-scan §7 | report-with-fix |
| DOC-DE1-a | `docs/config.md:19` | medium | `/doc-refresh` | DE-1 | doc-drift-scan §8 | report-with-fix |
| DOC-DE1-b | `docs/guide/webhooks.md:8` | medium | `/doc-refresh` | DE-1 | doc-drift-scan §8 | report-with-fix |
| DOC-DE2-a | `apps/api/src/config/env.schema.ts:8` | high | `/doc-refresh` | DE-2 | doc-drift-scan §9 | report-with-fix |
| DOC-DE2-b | `apps/api/src/config/env.schema.ts:9` | high | `/doc-refresh` | DE-2 | doc-drift-scan §9 | report-with-fix |
| DOC-DE3-a | `docs/config.md:14` | medium | `/doc-refresh` | DE-3 | doc-drift-scan §10 | report-with-fix |
| DOC-DE3-b | `docs/config.md:15` | medium | `/doc-refresh` | DE-3 | doc-drift-scan §10 | report-with-fix |
| DOC-DA1-a | `docs/api.md:33` | high | `/doc-refresh` | DA-1 | doc-drift-scan §11 | report-with-fix |
| DOC-DA1-b | `docs/api.md:38` | high | `/doc-refresh` | DA-1 | doc-drift-scan §11 | report-with-fix |
| DOC-DH1-a | `CHANGELOG.md:17` | high | `/doc-refresh` | DH-1 | doc-drift-scan §12 | report-with-fix |
| DOC-DH1-b | `CHANGELOG.md:6` | medium | `/doc-refresh` | DH-1 | doc-drift-scan §12 | report-flagged |
| DOC-DK1-a | `docs/runbooks/restore-db.md:15` | high | `/doc-refresh` | DK-1 | doc-drift-scan §13 | report-with-fix |
| DOC-DK1-b | `docs/runbooks/api-unavailable.md:17` | high | `/doc-refresh` | DK-1 | doc-drift-scan §13 | report-with-fix |
| DOC-DK2-a | `docs/runbooks/reports.md:8` | high | `/doc-refresh` | DK-2 | doc-drift-scan §14 | report-with-fix |
| DOC-DK2-b | `docs/runbooks/api-latency.md:3` | high | `/doc-refresh` | DK-2 | doc-drift-scan §14 | report-with-fix |
| DOC-DC1-a | `packages/sdk/README.md:14` | high | `/doc-refresh` | DC-1 | doc-sample-scan §1 | Unconfirmed — a scratch install + tsc settles |
| DOC-DC1-b | `packages/sdk/README.md:26` | high | `/doc-refresh` | DC-1 | doc-sample-scan §1 | Unconfirmed — a scratch install + tsc settles |
| DOC-DC2-a | `packages/py-money/README.md:15` | medium | `/doc-refresh` | DC-2 | doc-sample-scan §2 | report-with-fix |
| DOC-DC2-b | `packages/py-money/src/py_money/format.py:16` | medium | `/doc-refresh` | DC-2 | doc-sample-scan §2 | report-with-fix |
| DOC-DC3-a | `docs/api.md:45` | medium | `/doc-refresh` | DC-3 | doc-sample-scan §3 | report-with-fix |
| DOC-DC3-b | `docs/guide/webhooks.md:15` | medium | `/doc-refresh` | DC-3 | doc-sample-scan §3 | report-with-fix |
| DOC-DC4-a | `packages/py-money/pyproject.toml:30` | medium | `/doc-refresh` | DC-4 | doc-sample-scan §4 | report-with-fix |
| DOC-DC4-b | `package.json:19` | medium | `/doc-refresh` | DC-4 | doc-sample-scan §4 | report-with-fix |
| DOC-DA2-a | `apps/api/openapi.json:121` | medium | `/doc-refresh` | DA-2 | doc-sample-scan §5 | report-with-fix |
| DOC-DA2-b | `apps/api/openapi.json:25` | medium | `/doc-refresh` | DA-2 | doc-sample-scan §5 | report-with-fix |
| DOC-DS1-a | `README.md:16` | high | `/doc-refresh` | DS-1 | quickstart-verify §1 | Unconfirmed (static) — container lane settles |
| DOC-DS1-b | `CONTRIBUTING.md:12` | high | `/doc-refresh` | DS-1 | quickstart-verify §3 | Unconfirmed (static) — container lane settles |
| DOC-DD1-a | `packages/sdk/src/webhooks.ts:3` | medium | `/doc-refresh` | DD-1 | docstring-coverage §1 | report-flagged |
| DOC-DD1-b | `packages/py-money/src/py_money/allocate.py:4` | medium | `/doc-refresh` | DD-1 | docstring-coverage §1 | report-flagged |
| DOC-DD2-a | `packages/sdk/src/orders.ts:36` | medium | `/doc-refresh` | DD-2 | docstring-coverage §2 | report-with-fix |
| DOC-DD2-b | `packages/py-money/src/py_money/convert.py:17` | medium | `/doc-refresh` | DD-2 | docstring-coverage §2 | report-with-fix |
| DOC-DD3-a | `packages/sdk/src/client.ts:25` | low | `/doc-refresh` | DD-3 | docstring-coverage §3 | report-with-fix |
| DOC-DD3-b | `packages/py-money/src/py_money/__init__.py:3` | low | `/doc-refresh` | DD-3 | docstring-coverage §3 | report-with-fix |
| DOC-DF3-a | `docs/architecture.md:11` | medium | `/doc-refresh` | DF-3 | diagram-sync | report-with-fix |
| DOC-DF3-b | `docs/architecture.md:13` | medium | `/doc-refresh` | DF-3 | diagram-sync | report-with-fix |

Severity split: 0 critical · 16 high · 41 medium · 19 low. No BLOCKER: no runbook step acts on a resource whose old name now belongs to another one, and no setup step destroys data. HIGH is a primary-surface step that fails (a quickstart script, a runbook command or resource, an alert's runbook link, a required variable, a public endpoint, a published sample, a public breaking change); a secondary internal page is one step lower.

---

## DOC-DL1-a — The README links the deployment guide at its old path

```defect
id:       DOC-DL1-a
file:     README.md
line:     37
severity: medium
command:  /doc-refresh
class:    DL-1
owner:    documentation
bucket:   report-with-fix
detector: doc-structure-scan §1
anchor:   [deployment guide](docs/deploy.md)
match:    docs/deploy\.md|deployment guide
match:    missing|does not exist|doesn.t exist|no such|not found|dead|deleted|removed|renamed|moved|broken|404|resolves to (no|nothing)|no file|operations\.md
```

`docs/deploy.md` was moved to `docs/operations.md` (`git mv` in the staged history); the README link still points at the old file. The engine prints `docs/deploy.md does not exist; renamed -> docs/operations.md`. Fix: repoint the link.

## DOC-DL1-b — CONTRIBUTING links a commit-style guide that does not exist

```defect
id:       DOC-DL1-b
file:     CONTRIBUTING.md
line:     31
severity: medium
command:  /doc-refresh
class:    DL-1
owner:    documentation
bucket:   report-with-fix
detector: doc-structure-scan §1
anchor:   [commit message guide](docs/commit-style.md)
match:    commit-style|commit message guide
match:    missing|does not exist|doesn.t exist|no such|not found|dead|deleted|removed|renamed|moved|broken|404|resolves to (no|nothing)|no file
```

No `docs/commit-style.md` exists under any renderer form and no history names it. Fix: write the page or point the link at the Conventional Commits rules the paragraph already states.

## DOC-DL2-a — The README deep-links `#install-steps`; the setup page heading is "Installing"

```defect
id:       DOC-DL2-a
file:     README.md
line:     21
severity: medium
command:  /doc-refresh
class:    DL-2
owner:    documentation
bucket:   report-with-fix
detector: doc-structure-scan §2
anchor:   [install steps](docs/guide/setup.md#install-steps)
match:    install-steps
match:    anchor|fragment|heading|slug|missing|broken|does not exist|no such|installing
```

The target is under `docs_dir`, so the MkDocs `toc` slugger applies: its slugs are `getting-started`, `requirements`, `installing`, `next-steps`. No `install-steps`. Fix: link `#installing`, or give the heading `{#install-steps}`.

## DOC-DL2-b — The restore runbook links an anchor the operations page does not have

```defect
id:       DOC-DL2-b
file:     docs/runbooks/restore-db.md
line:     20
severity: medium
command:  /doc-refresh
class:    DL-2
owner:    documentation
bucket:   report-with-fix
detector: doc-structure-scan §2
anchor:   [backup section](../operations.md#restoring-a-backup)
match:    restoring-a-backup
match:    anchor|fragment|heading|slug|missing|broken|does(?: not|n.t) exist|no such|restore-from-a-backup
```

`docs/operations.md` is GitHub-rendered; its heading `## Restore from a backup` slugs to `restore-from-a-backup`. The runbook's `#restoring-a-backup` lands at the top of the page during an incident. Fix: the real slug.

## DOC-DL3-a — The webhooks guide sends readers to a Payrail reference that does not resolve

```defect
id:       DOC-DL3-a
file:     docs/guide/webhooks.md
line:     18
severity: low
command:  /doc-refresh
class:    DL-3
owner:    documentation
bucket:   Unconfirmed — NETWORK=1 settles
detector: doc-structure-scan §3
anchor:   (https://docs.payrail.invalid/webhooks/signatures)
match:    payrail
match:    dead|unreachable|does not resolve|resolve|DNS|NXDOMAIN|404|broken|external|\.invalid
```

The host is under the reserved `.invalid` TLD, so it fails DNS on every run: the fixture's stand-in for a vendor domain that went away (precedents § 6 flips: the reader is told to follow it). Offline the engine only counts the link (`DL-3 N/A (offline)`); `NETWORK=1` settles it.

## DOC-DL3-b — The SDK README points 1.x users at migration notes on a host that does not resolve

```defect
id:       DOC-DL3-b
file:     packages/sdk/README.md
line:     44
severity: low
command:  /doc-refresh
class:    DL-3
owner:    documentation
bucket:   Unconfirmed — NETWORK=1 settles
detector: doc-structure-scan §3
anchor:   (https://sdk-archive.tallyhook.invalid/migrate-1x)
match:    sdk-archive|migration notes
match:    dead|unreachable|does not resolve|resolve|DNS|NXDOMAIN|404|broken|external|\.invalid
```

Same shape as DOC-DL3-a, on the README the npm registry renders. Unconfirmed until the online lychee lane runs twice.

## DOC-DL4-a — The docs build cannot fail: no `--strict` and no `strict: true`

```defect
id:       DOC-DL4-a
file:     .github/workflows/docs.yml
line:     18
severity: medium
command:  /doc-refresh
class:    DL-4
owner:    documentation
bucket:   report-with-fix
detector: doc-structure-scan §4
anchor:   run: mkdocs build --site-dir site
match:    mkdocs
match:    strict|cannot fail|can.t fail|never fail|does not fail|doesn.t fail|exit 0|silen|green|warn|report only|not fail
```

`mkdocs.yml` sets `validation.links.anchors: warn` but no `strict`, and the job runs `mkdocs build` without `--strict`, so every warning (the broken nav entry DOC-DF2-a, the missing anchors) exits 0. The engine prints this CI line and `mkdocs.yml:0 strict` for the same root cause. Proof: plant a broken link in a scratch copy, the build stays green. Fix: `strict: true`.

## DOC-DL4-b — The link check reports and never fails the job (`fail: false`)

```defect
id:       DOC-DL4-b
file:     .github/workflows/docs.yml
line:     23
severity: medium
command:  /doc-refresh
class:    DL-4
owner:    documentation
bucket:   report-with-fix
detector: doc-structure-scan §4
anchor:   uses: lycheeverse/lychee-action@v2
match:    lychee
match:    fail: ?false|cannot fail|can.t fail|never fail|does not fail|doesn.t fail|exit 0|silen|green|warn|report only|not fail
```

lychee-action v2 with `fail: false` turns every broken link into a comment. Fix: `fail: true` (and keep `--include-fragments`).

## DOC-DK3-a — The ApiUnavailable alert links a runbook that was renamed

```defect
id:       DOC-DK3-a
file:     deploy/alerts/rules.yml
line:     11
severity: high
command:  /doc-refresh
class:    DK-3
owner:    documentation
bucket:   report-with-fix
detector: doc-structure-scan §5
anchor:   runbook_url: docs/runbooks/api-down.md
match:    api-down
match:    missing|does(?: not|n.t) exist|doesn.t exist|no such|(?:not|n.t) found|dead|deleted|removed|renamed|moved|broken|404|resolves to (no|nothing)|no file|api-unavailable
```

`docs/runbooks/api-down.md` became `api-unavailable.md` (history step 12); the page the on-call engineer opens from the alert is a 404. HIGH: an alert's runbook. Fix: repoint `runbook_url` in the same change as the rename.

## DOC-DK3-b — An API error links an anchor the troubleshooting page does not have

```defect
id:       DOC-DK3-b
file:     apps/api/src/common/errors.ts
line:     5
severity: medium
command:  /doc-refresh
class:    DK-3
owner:    documentation
bucket:   report-with-fix
detector: doc-structure-scan §5
anchor:   docsUrl: 'docs/troubleshooting.md#tls-handshake-failed'
match:    tls-handshake
match:    anchor|fragment|heading|slug|missing|broken|does not exist|no such|tls-errors
```

The `TLS_HANDSHAKE` error's `docs` link targets `#tls-handshake-failed`; `docs/troubleshooting.md` has `## TLS errors` (`tls-errors`). Fix: the anchor in the code string, or an `<a id>` on the heading.

## DOC-DX1-a — ADR 0003 says "Superseded by 0006"; 0006 never says it supersedes 0003

```defect
id:       DOC-DX1-a
file:     docs/adr/0006-redis-rate-limit.md
line:     5
severity: medium
command:  /doc-refresh
class:    DX-1
owner:    documentation
bucket:   report-flagged
detector: doc-structure-scan §6
anchor:   Status: Accepted
match:    0003|in-memory
match:    supersed|one-way|reciproc|back-?link
```

One-way supersession: a reader of 0006 cannot find the decision it replaced. The engine cites 0006 (the end to edit). Unproven link: is 0006 a whole replacement (§ 30)? Its body suggests yes. Fix: `Supersedes [0003](0003-in-memory-rate-limit.md)` in 0006.

## DOC-DX1-b — ADR 0005 supersedes ADR-0009, which does not exist

```defect
id:       DOC-DX1-b
file:     docs/adr/0005-cursor-pagination.md
line:     7
severity: medium
command:  /doc-refresh
class:    DX-1
owner:    documentation
bucket:   report-flagged
detector: doc-structure-scan §6
anchor:   Supersedes ADR-0009
match:    0009|ADR-?9\b
match:    supersed|does not exist|missing|no such|absent|dangling|target
```

There is no 0009 (the set is 0001-0008 and 0010). A person decides which ADR was meant, or records the offset-pagination decision that 0005 replaced.

## DOC-DX2-a — ADR 0007 has a status outside the template vocabulary

```defect
id:       DOC-DX2-a
file:     docs/adr/0007-money-as-integers.md
line:     5
severity: low
command:  /doc-refresh
class:    DX-2
owner:    documentation
bucket:   report-with-fix
detector: doc-structure-scan §7
anchor:   Status: Parked
match:    parked
match:    status|vocabular|template|not (a )?valid|unknown|outside
```

`docs/adr/template.md` declares Proposed, Accepted, Rejected, Deprecated, Superseded; `Parked` is none of them, so the engine prints WRONG (a declared vocabulary), not CHECK. Fix: a status from the template (Proposed, by its body).

## DOC-DX2-b — The ADR index lists 0004 as Proposed; the ADR says Accepted

```defect
id:       DOC-DX2-b
file:     docs/adr/README.md
line:     11
severity: low
command:  /doc-refresh
class:    DX-2
owner:    documentation
bucket:   report-with-fix
detector: doc-structure-scan §7
anchor:   | BullMQ for every queue | Proposed |
match:    0004|BullMQ
match:    index|README|disagree|mismatch|says|out of (date|sync)|stale|Accepted
```

`0004-bullmq-for-queues.md` reads `Status: Accepted` (and supersedes 0002); the index row was never updated. Fix: the index row.

## DOC-DX3-a — Two ADRs share the number 0008

```defect
id:       DOC-DX3-a
file:     docs/adr/0008-sdk-codegen.md
line:     1
severity: low
command:  /doc-refresh
class:    DX-3
owner:    documentation
bucket:   report-with-fix
detector: doc-structure-scan §8
anchor:   # 8. Generate the SDK from the spec
match:    0008
match:    duplicate|collid|twice|two (files|ADRs)|same number|reuse|shared|already|used by (2|two)|2 files
```

`0008-openapi-first.md` and `0008-sdk-codegen.md`; the index lists only the first. Fix: renumber the proposed one to the next free number (0011) and add it to the index.

## DOC-DX3-b — ADR 0010 is titled "11."

```defect
id:       DOC-DX3-b
file:     docs/adr/0010-tenant-scoped-keys.md
line:     1
severity: low
command:  /doc-refresh
class:    DX-3
owner:    documentation
bucket:   report-with-fix
detector: doc-structure-scan §8
anchor:   # 11. Tenant-scoped API keys
match:    0010|\b11\b|tenant-scoped
match:    title|heading|mismatch|differs|contradict|file (name|number)
```

The file number and the title number disagree, so a citation by number lands on the wrong decision. Fix: `# 10. …`.

## DOC-DH2-a — The changelog lists 1.3.0 below 1.2.0

```defect
id:       DOC-DH2-a
file:     CHANGELOG.md
line:     49
severity: low
command:  /doc-refresh
class:    DH-2
owner:    documentation
bucket:   report-with-fix
detector: doc-structure-scan §9
anchor:   ## [1.3.0] - 2026-04-14
match:    1\.3\.0
match:    order|descending|below|above|after|sort|sequence
```

Keep a Changelog orders releases newest first; 1.3.0 sits under 1.2.0. Fix: move the section above 1.2.0.

## DOC-DH2-b — The 1.1.0 release date is not ISO 8601

```defect
id:       DOC-DH2-b
file:     CHANGELOG.md
line:     55
severity: low
command:  /doc-refresh
class:    DH-2
owner:    documentation
bucket:   report-with-fix
detector: doc-structure-scan §9
anchor:   ## [1.1.0] - 03/02/2026
match:    1\.1\.0|03/02/2026
match:    ISO|date|YYYY-MM-DD|format
```

`03/02/2026` reads as March or February depending on the reader. Fix: `2026-02-03` (the compare links date the tag).

## DOC-DI1-a — The Webhooks page has no Arabic translation

```defect
id:       DOC-DI1-a
file:     docs/guide/webhooks.md
line:     1
severity: low
command:  /doc-refresh
class:    DI-1
owner:    documentation
bucket:   report-flagged
detector: doc-structure-scan §10
anchor:   # Webhooks
match:    webhooks
match:    \bar\b|arabic|translat|locale
match:    missing|no |absent|lacks|untranslated|not translated|fallback
```

`mkdocs.yml` declares `ar` through mkdocs-static-i18n with `fallback_to_default: true`, which hides the gap by serving the English page. No lag policy is declared anywhere. A person decides: translate, or declare the minimum content per locale.

## DOC-DI1-b — The Reports page has no Arabic translation

```defect
id:       DOC-DI1-b
file:     docs/guide/reports.md
line:     1
severity: low
command:  /doc-refresh
class:    DI-1
owner:    documentation
bucket:   report-flagged
detector: doc-structure-scan §10
anchor:   # Reports
match:    reports
match:    \bar\b|arabic|translat|locale
match:    missing|no |absent|lacks|untranslated|not translated|fallback
```

Same as DOC-DI1-a for `docs/guide/reports.md`.

## DOC-DI2-a — The Arabic billing page predates two sections of its source

```defect
id:       DOC-DI2-a
file:     docs/guide/ar/billing.md
line:     1
severity: low
command:  /doc-refresh
class:    DI-2
owner:    documentation
bucket:   report-flagged
detector: doc-structure-scan §11
anchor:   # الفوترة
match:    billing
match:    stale|outdated|out of date|behind|older|changed (since|after)|after the translation|not (been )?updated|lag
```

With the staged history, `docs/guide/billing.md` was last committed 2026-08-03 (credit notes, refunds) and the translation 2026-05-04, with no source-commit marker and no outdated banner: the engine prints CHECK (commit-time comparison). Without `stage-history.sh` the copy has one commit and this row is history-blind.

## DOC-DI2-b — The Arabic SDK page is stale: it predates the source page's Errors section

```defect
id:       DOC-DI2-b
file:     docs/guide/ar/sdk.md
line:     1
severity: low
command:  /doc-refresh
class:    DI-2
owner:    documentation
bucket:   report-flagged
detector: doc-structure-scan §11
anchor:   # حزمة SDK
match:    sdk
match:    stale|outdated|out of date|behind|older|changed (since|after)|after the translation|not (been )?updated|lag
```

As DOC-DI2-a: `docs/guide/sdk.md` committed 91 days after its translation, no marker, no banner.

## DOC-DI3-a — The Arabic setup page still runs `pnpm dev:all`; the source runs `pnpm dev`

```defect
id:       DOC-DI3-a
file:     docs/guide/ar/setup.md
line:     17
severity: medium
command:  /doc-refresh
class:    DI-3
owner:    documentation
bucket:   report-with-fix
detector: doc-structure-scan §12
anchor:   pnpm dev:all
match:    dev:all|code block|block differs
match:    translat|arabic|source page|the source|english|diverg|differ
```

The translation's install block differs from `docs/guide/setup.md` in its last command, so an Arabic reader runs a script that does not exist. The engine prints the DI-3 row (claim = the differing line) and a DR-3 MISS on the same line; one finding.

## DOC-DI3-b — The Arabic home page links the old filename of the setup page

```defect
id:       DOC-DI3-b
file:     docs/guide/ar/index.md
line:     6
severity: medium
command:  /doc-refresh
class:    DI-3
owner:    documentation
bucket:   report-with-fix
detector: doc-structure-scan §12
anchor:   [البدء](getting-started.md)
match:    getting-started
match:    translat|arabic|source page|the source|english|diverg|differ|setup\.md|renamed|old
```

The source links `setup.md`; the translation still links `getting-started.md`, renamed in history step 8. The engine also prints DL-1 MISS on the same line (`renamed -> docs/guide/ar/setup.md`); one finding. Fix: `setup.md`.

## DOC-DF1-a — The published billing page ships "Refunds: TBD."

```defect
id:       DOC-DF1-a
file:     docs/guide/billing.md
line:     18
severity: low
command:  /doc-refresh
class:    DF-1
owner:    documentation
bucket:   report-with-fix
detector: doc-structure-scan §13
anchor:   Refunds: TBD.
match:    TBD|refunds?
match:    placeholder|TBD|unfinished|empty|stub
```

A placeholder in prose on the merchant-facing site. Fix: the refund rules, or keep the section out until it exists.

## DOC-DF1-b — The operations page never filled in the on-call schedule

```defect
id:       DOC-DF1-b
file:     docs/operations.md
line:     21
severity: low
command:  /doc-refresh
class:    DF-1
owner:    documentation
bucket:   report-with-fix
detector: doc-structure-scan §13
anchor:   Pager schedule: <insert the on-call schedule link>.
match:    insert|on-call|pager
match:    placeholder|unfinished|stub|<insert|never filled
```

`<insert …>` in prose (not a config fence, so § 6 does not apply). Fix: the schedule link.

## DOC-DF2-a — The nav entry for Billing points at a page that does not exist

```defect
id:       DOC-DF2-a
file:     mkdocs.yml
line:     33
severity: low
command:  /doc-refresh
class:    DF-2
owner:    documentation
bucket:   report-with-fix
detector: doc-structure-scan §14
anchor:   - Billing: billing/overview.md
match:    billing/overview
match:    nav|missing|does not exist|moved|no (such )?(page|file)|broken
```

The page is `docs/guide/billing.md`; `billing/overview.md` is nowhere under `docs_dir`. Non-strict MkDocs only warns (DOC-DL4-a). Fix: `- Billing: billing.md`.

## DOC-DF2-b — The Legacy SSO page is an orphan

```defect
id:       DOC-DF2-b
file:     docs/guide/legacy-sso.md
line:     1
severity: low
command:  /doc-refresh
class:    DF-2
owner:    documentation
bucket:   report-flagged
detector: doc-structure-scan §14
anchor:   # Legacy SSO
match:    legacy-sso|legacy sso
match:    orphan|not in (the )?nav|unreachable|linked from nowhere|no (inbound )?link|nav
```

In no nav entry, no `not_in_nav` pattern, linked from no page. A person decides: link it, list it in `not_in_nav`, or delete it.

## DOC-DR1-a — The README names the config file by its old name

```defect
id:       DOC-DR1-a
file:     README.md
line:     32
severity: medium
command:  /doc-refresh
class:    DR-1
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §1
anchor:   Configuration is loaded by `apps/api/src/config/app.config.ts`
match:    app\.config
match:    missing|does not exist|doesn.t exist|no such|not found|dead|deleted|removed|renamed|moved|broken|404|resolves to (no|nothing)|no file|config\.loader
```

`apps/api/src/config/app.config.ts` was renamed `config.loader.ts` (history step 3). The ladder misses it everywhere; the engine's detail carries `renamed -> apps/api/src/config/config.loader.ts`. Fix: the new path.

## DOC-DR1-b — The SDK README names a retry-policy file that was deleted

```defect
id:       DOC-DR1-b
file:     packages/sdk/README.md
line:     33
severity: medium
command:  /doc-refresh
class:    DR-1
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §1
anchor:   Retries are configured in `packages/sdk/src/retry-policy.ts`
match:    retry-policy
match:    missing|does not exist|doesn.t exist|no such|not found|dead|deleted|removed|renamed|moved|broken|404|resolves to (no|nothing)|no file|http\.ts
```

`packages/sdk/src/retry-policy.ts` was folded into `src/http.ts` (history step 5, `deleted in <sha>`). Fix: name the client option, not a file.

## DOC-DR2-a — The architecture page names a processor class that does not exist

```defect
id:       DOC-DR2-a
file:     docs/architecture.md
line:     19
severity: low
command:  /doc-refresh
class:    DR-2
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §2
anchor:   The nightly `ReportsDigestProcessor`
match:    ReportsDigestProcessor
match:    not defined|defined nowhere|does not exist|no such|renamed|ReportsDailyProcessor|dead|missing|unknown
```

The class is `ReportsDailyProcessor` (`apps/api/src/reports/reports.processor.ts`); `ReportsDigestProcessor` is defined nowhere. LOW: an internal architecture page (secondary surface).

## DOC-DR2-b — The API README documents `ordersService.cancelAll()`, which OrdersService does not have

```defect
id:       DOC-DR2-b
file:     apps/api/README.md
line:     38
severity: medium
command:  /doc-refresh
class:    DR-2
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §2
anchor:   `ordersService.cancelAll()`
match:    cancelAll
match:    not defined|defined nowhere|does not exist|no such|no method|dead|missing|unknown
```

No such method: `ordersService` is the project's receiver; `OrdersService` has `list`, `create`, `get`, `cancel` and `exportCsv`. Fix: remove the paragraph, or build the method if bulk cancellation is promised.

## DOC-DR3-a — The README quickstart runs `pnpm dev:all`; no manifest defines it

```defect
id:       DOC-DR3-a
file:     README.md
line:     18
severity: high
command:  /doc-refresh
class:    DR-3
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §3
anchor:   pnpm dev:all
match:    dev:all
match:    script|not (defined|found)|no such|missing|dead|renamed|does not exist
```

Root scripts are `dev`, `dev:api`, `dev:worker`; no workspace package has `dev:all`. The last quickstart step fails. Same root cause as DOC-DI3-a's Arabic copy. Fix: `pnpm dev`.

## DOC-DR3-b — CONTRIBUTING runs `make seed-db`; the Makefile target is `db-seed`

```defect
id:       DOC-DR3-b
file:     CONTRIBUTING.md
line:     14
severity: high
command:  /doc-refresh
class:    DR-3
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §3
anchor:   make seed-db
match:    seed-db
match:    target|Makefile|db-seed|not (defined|found)|no such|missing|dead|renamed
```

Fix: `make db-seed` (or `pnpm db:seed`).

## DOC-DR4-a — The API README passes `--legacy-import`, which the CLI no longer declares

```defect
id:       DOC-DR4-a
file:     apps/api/README.md
line:     30
severity: medium
command:  /doc-refresh
class:    DR-4
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §4
anchor:   tallyhook import orders.csv --legacy-import
match:    legacy-import
match:    flag|option|not (declared|defined|accepted|recogni[sz]ed)|unknown|no such|removed|dead
```

`apps/api/src/cli/args.ts` (the `tallyhook` bin) declares `--dry-run` and `--batch-size` for `import`; `--legacy-import` was removed in history step 10 (`feat(cli)!`). Commander rejects the unknown option. Same removal as DOC-DH1-b.

## DOC-DR4-b — The backfill command uses `--since`; the script parses `--from`

```defect
id:       DOC-DR4-b
file:     docs/guide/reports.md
line:     11
severity: medium
command:  /doc-refresh
class:    DR-4
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §4
anchor:   node scripts/backfill-totals.mjs --since 2026-01-01
match:    since
match:    flag|option|not (declared|defined|accepted|recogni[sz]ed)|unknown|no such|removed|dead|--from
```

`scripts/backfill-totals.mjs` declares `--from`, `--to`, `--dry-run`. `parseArgs` in strict mode throws on `--since`. Fix: `--from`.

## DOC-DR5-a — The SDK README presents the deprecated `getOrders()` as the way to fetch orders

```defect
id:       DOC-DR5-a
file:     packages/sdk/README.md
line:     29
severity: medium
command:  /doc-refresh
class:    DR-5
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §5
anchor:   Call `client.orders.getOrders()`
match:    getOrders
match:    deprecat|instead|removed in 3|goes away
```

`packages/sdk/src/orders.ts` marks `getOrders` `@deprecated use OrdersApi.list; it goes away in 3.0`, and the README says nothing. Fix: `client.orders.list()`.

## DOC-DR5-b — The API reference lists `GET /orders/export` with no deprecation note

```defect
id:       DOC-DR5-b
file:     docs/api.md
line:     24
severity: medium
command:  /doc-refresh
class:    DR-5
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §5
anchor:   | `GET` | `/orders/export` |
match:    orders/export
match:    deprecat
```

The spec marks the operation `deprecated: true` (the controller says use `/v1/reports/monthly?format=csv`). The table presents it as current. Fix: mark it deprecated and name the replacement.

## DOC-DS2-a — The README admits Node 20; every pin starts at 22

```defect
id:       DOC-DS2-a
file:     README.md
line:     8
severity: medium
command:  /doc-refresh
class:    DS-2
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §6
anchor:   - Node 20+ and pnpm 10
match:    node ?(\.?js)? ?20|20\+
match:    nvmrc|engines|22|pin
```

`.nvmrc` 22, root `engines.node` `>=22.12`, the Dockerfile `node:22-alpine` and CI `node-version: 22`. Fix: `Node 22.12+`.

## DOC-DS2-b — CONTRIBUTING admits Python 3.10; py-money requires 3.12

```defect
id:       DOC-DS2-b
file:     CONTRIBUTING.md
line:     8
severity: medium
command:  /doc-refresh
class:    DS-2
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §6
anchor:   Python 3.10 or later
match:    python ?3\.10|3\.10
match:    requires-python|3\.12|pin|pyproject
```

`packages/py-money/pyproject.toml` `requires-python = ">=3.12"`, CI `python-version: "3.12"`. Fix: `Python 3.12 or later`.

## DOC-DS3-a — The contributor setup starts with `npm install` in a pnpm workspace

```defect
id:       DOC-DS3-a
file:     CONTRIBUTING.md
line:     11
severity: medium
command:  /doc-refresh
class:    DS-3
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §7
anchor:   npm install
match:    \bnpm (install|i|ci)\b
match:    pnpm|lockfile|package ?manager|packageManager|corepack
```

The root pins `packageManager: pnpm@10.18.3` and ships `pnpm-lock.yaml`; npm ignores the workspace protocol and the lockfile. Fix: `pnpm install`.

## DOC-DS3-b — The API README starts the service with yarn

```defect
id:       DOC-DS3-b
file:     apps/api/README.md
line:     21
severity: medium
command:  /doc-refresh
class:    DS-3
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §7
anchor:   yarn start:dev
match:    \byarn\b
match:    pnpm|lockfile|package ?manager|packageManager|corepack
```

Same pin as DOC-DS3-a; corepack refuses yarn in this workspace. Fix: `pnpm start:dev` (or `pnpm --filter @tallyhook/api start:dev`).

## DOC-DE1-a — The configuration reference documents `SEARCH_INDEX_URL`, which nothing reads

```defect
id:       DOC-DE1-a
file:     docs/config.md
line:     19
severity: medium
command:  /doc-refresh
class:    DE-1
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §8
anchor:   | `SEARCH_INDEX_URL` |
match:    SEARCH_INDEX_URL
match:    read|nothing|no code|unused|dead|not in the schema|undefined|nowhere
```

Not in `env.schema.ts`, not read by any code, not in `.env.example`, the ConfigMap or the compose file. Fix: remove the row.

## DOC-DE1-b — The webhooks guide tells readers to set `WEBHOOK_SIGNING_KEY`; the API reads `WEBHOOK_SECRET`

```defect
id:       DOC-DE1-b
file:     docs/guide/webhooks.md
line:     8
severity: medium
command:  /doc-refresh
class:    DE-1
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §8
anchor:   Set the `WEBHOOK_SIGNING_KEY` environment variable
match:    WEBHOOK_SIGNING_KEY
match:    read|nothing|no code|unused|dead|WEBHOOK_SECRET|not in the schema|nowhere|renamed
```

Setting the documented name leaves the required `WEBHOOK_SECRET` unset and the API refuses to boot. Fix: the real name.

## DOC-DE2-a — A required variable, `PAYMENTS_WEBHOOK_SECRET`, appears in no doc and no example

```defect
id:       DOC-DE2-a
file:     apps/api/src/config/env.schema.ts
line:     8
severity: high
command:  /doc-refresh
class:    DE-2
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §9
anchor:   PAYMENTS_WEBHOOK_SECRET: z.string().min(32),
match:    PAYMENTS_WEBHOOK_SECRET
match:    undocumented|(?:not|n.t) documented|no doc|in no doc|missing from|\.env\.example|nowhere|(?:not|n.t) (listed|mentioned)|required
```

No `.default()`, no `.optional()`: the API refuses to boot without it, and neither `docs/config.md`, the setup pages nor `apps/api/.env.example` mention it (§ 24 searched). Fix: a row in the reference and a commented line in the example.

## DOC-DE2-b — A required variable, `FX_RATES_API_KEY`, appears in no doc and no example

```defect
id:       DOC-DE2-b
file:     apps/api/src/config/env.schema.ts
line:     9
severity: high
command:  /doc-refresh
class:    DE-2
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §9
anchor:   FX_RATES_API_KEY: z.string(),
match:    FX_RATES_API_KEY
match:    undocumented|not documented|no doc|in no doc|missing from|\.env\.example|nowhere|not (listed|mentioned)|required
```

Same as DOC-DE2-a.

## DOC-DE3-a — The reference says `RETRY_LIMIT` defaults to 5; the schema defaults to 3

```defect
id:       DOC-DE3-a
file:     docs/config.md
line:     14
severity: medium
command:  /doc-refresh
class:    DE-3
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §10
anchor:   | `RETRY_LIMIT` | `5` |
match:    RETRY_LIMIT
match:    default
match:    \b3\b|\b5\b|schema
```

`env.schema.ts`: `RETRY_LIMIT: z.coerce.number().int().default(3)`. Fix: `3`.

## DOC-DE3-b — The reference lists `LOG_FORMAT` values `json` or `text`; the schema allows `json` or `pretty`

```defect
id:       DOC-DE3-b
file:     docs/config.md
line:     15
severity: medium
command:  /doc-refresh
class:    DE-3
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §10
anchor:   `json` or `text`.
match:    LOG_FORMAT
match:    text|pretty|enum|values?|allowed
```

`z.enum(['json', 'pretty'])`: `text` fails validation at boot. Fix: `json` or `pretty`.

## DOC-DA1-a — The API reference documents `POST /orders/{id}/void`; the API serves `/cancel`

```defect
id:       DOC-DA1-a
file:     docs/api.md
line:     33
severity: high
command:  /doc-refresh
class:    DA-1
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §11
anchor:   call `POST /orders/{id}/void`
match:    void
match:    not served|not routed|no route|no handler|not in the spec|no (spec )?path|404|does not exist|missing|unserved|removed|renamed|cancel
```

Neither `openapi.json` nor `OrdersController` has `/void`; `POST /orders/{id}/cancel` is the served route. HIGH: public API docs. Direction (§ 16): the spec is the contract (ADR 0008), so the doc moves.

## DOC-DA1-b — The API reference documents `GET /reports/daily`, which no spec path or route serves

```defect
id:       DOC-DA1-b
file:     docs/api.md
line:     38
severity: high
command:  /doc-refresh
class:    DA-1
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §11
anchor:   `GET /reports/daily` returns
match:    reports/daily
match:    not served|not routed|no route|no handler|not in the spec|no (spec )?path|404|does not exist|missing|unserved|removed|renamed
```

Only `GET /reports/monthly` exists; the daily totals are built by a job, not served. Fix: remove the section or point at the monthly report.

## DOC-DH1-a — The breaking `feat(api)!: drop the page param` shipped in 1.5.0 with no changelog line

```defect
id:       DOC-DH1-a
file:     CHANGELOG.md
line:     17
severity: high
command:  /doc-refresh
class:    DH-1
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §12
anchor:   ## [1.5.0] - 2026-05-25
match:    \bpage\b
match:    breaking|!:|not announced|missing|no (release )?note|unannounced|omit|not mention
```

History: `v1.4.0..v1.5.0` holds `feat(api)!: drop the page param`; the 1.5.0 section mentions cursor listing but not that `page` is gone, so `GET /v1/orders?page=2` clients break silently. HIGH: a public API. Requires `stage-history.sh`; without tags the engine prints `DH-1 N/A (no release tags)`. Fix: a `### Changed` **BREAKING** line (§ 25 endorses retro-adding).

## DOC-DH1-b — The breaking removal of `--legacy-import` is missing from `[Unreleased]`

```defect
id:       DOC-DH1-b
file:     CHANGELOG.md
line:     6
severity: medium
command:  /doc-refresh
class:    DH-1
owner:    documentation
bucket:   report-flagged
detector: doc-drift-scan §12
anchor:   ## [Unreleased]
match:    legacy-import
match:    breaking|!:|not announced|missing|no (release )?note|unannounced|omit|not mention|Unreleased
```

History: `v1.5.0..HEAD` holds `feat(cli)!: drop the --legacy-import flag`; the Unreleased section does not mention it. Unproven link: the CLI ships inside the API image, not as a published package (MEDIUM).

## DOC-DK1-a — The restore runbook runs `make restore-db`; the target is `db-restore`

```defect
id:       DOC-DK1-a
file:     docs/runbooks/restore-db.md
line:     15
severity: high
command:  /doc-refresh
class:    DK-1
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §13
anchor:   make restore-db SNAPSHOT=latest
match:    make restore-db
match:    target|Makefile|db-restore|not (defined|found)|no such|missing|dead|renamed
```

The step fails at 2 am with `No rule to make target`. The engine prints DR-3 inside a runbook as DK-1. Fix: `make db-restore`.

## DOC-DK1-b — The failover step passes `--region`; the script parses `--to`

```defect
id:       DOC-DK1-b
file:     docs/runbooks/api-unavailable.md
line:     17
severity: high
command:  /doc-refresh
class:    DK-1
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §13
anchor:   node scripts/failover.mjs --region standby
match:    region
match:    flag|option|(?:not|n.t) (declared|defined|accepted|recogni[sz]ed)|unknown|no such|removed|dead|--to
```

`scripts/failover.mjs` declares `--to <primary|standby>` and `--dry-run`. Fix: `--to standby`.

## DOC-DK2-a — The reports runbook inspects CronJob `reports-nightly`; the manifest names `reports-daily`

```defect
id:       DOC-DK2-a
file:     docs/runbooks/reports.md
line:     8
severity: high
command:  /doc-refresh
class:    DK-2
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §14
anchor:   kubectl -n tallyhook get cronjob reports-nightly
match:    reports-nightly
match:    cronjob|reports-daily|no (such )?(cronjob|resource)|(?:not|n.t) (found|declared)|renamed|missing|does(?: not|n.t) exist
```

`deploy/k8s/reports-cronjob.yaml` declares `CronJob/reports-daily` in namespace `tallyhook`; the next step of the same runbook already uses the right name. Not BLOCKER: the old name belongs to nothing else. Fix: `reports-daily`.

## DOC-DK2-b — The latency runbook names an alert the rules no longer declare

```defect
id:       DOC-DK2-b
file:     docs/runbooks/api-latency.md
line:     3
severity: high
command:  /doc-refresh
class:    DK-2
owner:    documentation
bucket:   report-with-fix
detector: doc-drift-scan §14
anchor:   the `ApiHighLatency` alert
match:    ApiHighLatency
match:    alert|rule|ApiLatencyHigh|renamed|(?:not|n.t) (declared|defined)|missing|no such
```

`deploy/alerts/rules.yml` declares `ApiLatencyHigh` (and links this runbook); a search for `ApiHighLatency` finds nothing. Fix: the declared name.

## DOC-DC1-a — The SDK quick start imports `createOrderClient`, which the package does not export

```defect
id:       DOC-DC1-a
file:     packages/sdk/README.md
line:     14
severity: high
command:  /doc-refresh
class:    DC-1
owner:    documentation
bucket:   Unconfirmed — a scratch install + tsc settles
detector: doc-sample-scan §1
anchor:   import { createOrderClient } from '@tallyhook/sdk';
match:    createOrderClient
match:    export|TS2305|no exported member|compile|missing|renamed|createClient|does not exist
```

`packages/sdk/src/index.ts` exports `createClient`; the expected compiler error is TS2305 (no exported member). The fixture has no `node_modules`, so §1 prints NOT-RUN until a scratch install runs tsc; the missing export is visible statically. HIGH: the README the registry renders.

## DOC-DC1-b — The listing sample calls `list(50, true)`; `list` takes one options object

```defect
id:       DOC-DC1-b
file:     packages/sdk/README.md
line:     26
severity: high
command:  /doc-refresh
class:    DC-1
owner:    documentation
bucket:   Unconfirmed — a scratch install + tsc settles
detector: doc-sample-scan §1
anchor:   const page = await client.orders.list(50, true);
match:    list\(50|orders\.list
match:    TS2554|argument|arity|signature|ListOptions|compile|expected 1|options object
```

`OrdersApi.list(opts: ListOptions = {})` takes one argument; the expected compiler error is TS2554 (expected 0-1 arguments, got 2). Fix: `list({ limit: 50 })`.

## DOC-DC2-a — The README doctest states `101`; `to_minor(1.005, "EUR")` returns 100

```defect
id:       DOC-DC2-a
file:     packages/py-money/README.md
line:     15
severity: medium
command:  /doc-refresh
class:    DC-2
owner:    documentation
bucket:   report-with-fix
detector: doc-sample-scan §2
anchor:   >>> to_minor(1.005, "EUR")
match:    1\.005|101
match:    100|doctest|half.?even|round|output|expected
```

`convert.py` rounds half to even (`ROUND_HALF_EVEN`); the README still shows the old half-up result. `pytest --doctest-glob='*.md'` in a scratch copy fails on this line (measured: `Expected: 101 / Got: 100`). Contract question first (§ 16): the docstring and the tests say 100.

## DOC-DC2-b — The `format_amount` docstring doctest calls `format_minor`, its old name

```defect
id:       DOC-DC2-b
file:     packages/py-money/src/py_money/format.py
line:     16
severity: medium
command:  /doc-refresh
class:    DC-2
owner:    documentation
bucket:   report-with-fix
detector: doc-sample-scan §2
anchor:   >>> format_minor(1050, "EUR")
match:    format_minor
match:    NameError|not defined|renamed|format_amount|doctest|does not exist
```

`--doctest-modules` on the module raises NameError. Fix: `format_amount(1050, "EUR")`.

## DOC-DC3-a — The committed retry snippet no longer matches lines 5-12 of `retry.ts`

```defect
id:       DOC-DC3-a
file:     docs/api.md
line:     45
severity: medium
command:  /doc-refresh
class:    DC-3
owner:    documentation
bucket:   report-with-fix
detector: doc-sample-scan §3
anchor:   // apps/api/src/billing/retry.ts#L5-L12
match:    retry\.ts|backoffMs
match:    diverg|differs|stale|out of (date|sync)|embed|jitter|snippet
```

The repo uses embedme (`docs:embed`); the region now has a base delay and jitter, the doc still shows `1000 * 2 ** attempt`. `embedme --verify` would fail (and no CI step runs it: DOC-DC4-b). Fix: re-embed.

## DOC-DC3-b — The webhooks guide embeds `examples/verify-signature.ts`, which was deleted

```defect
id:       DOC-DC3-b
file:     docs/guide/webhooks.md
line:     15
severity: medium
command:  /doc-refresh
class:    DC-3
owner:    documentation
bucket:   report-with-fix
detector: doc-sample-scan §3
anchor:   --8<-- "examples/verify-signature.ts"
match:    verify-signature
match:    missing|does not exist|deleted|removed|snippet|embed|include
```

`pymdownx.snippets` with `check_paths: false` renders nothing where the verification code should be; `examples/` was removed in history step 7. Fix: inline the sample or point at the SDK's `verifyWebhookSignature`.

## DOC-DC4-a — py-money configures a doctest harness that CI never reaches

```defect
id:       DOC-DC4-a
file:     packages/py-money/pyproject.toml
line:     30
severity: medium
command:  /doc-refresh
class:    DC-4
owner:    documentation
bucket:   report-with-fix
detector: doc-sample-scan §4
anchor:   addopts = "--doctest-glob='*.md' --doctest-modules"
match:    doctest
match:    \bCI\b|workflow|never (run|collected)|not (run|collected)|tests/|testpaths
```

CI runs `pytest packages/py-money/tests`; with `testpaths = ["tests"]` the README and the `src/` docstrings are never collected, which is why DOC-DC2-a/b survive. Mutation proof: a broken README example keeps the CI command green. Fix: run `pytest` from the package root over `README.md` and `src/`.

## DOC-DC4-b — embedme keeps snippets in sync, but no CI step runs `embedme --verify`

```defect
id:       DOC-DC4-b
file:     package.json
line:     19
severity: medium
command:  /doc-refresh
class:    DC-4
owner:    documentation
bucket:   report-with-fix
detector: doc-sample-scan §4
anchor:   "docs:embed": "embedme README.md docs/api.md"
match:    embedme
match:    \bCI\b|workflow|--verify|never (run|runs)|not run
```

The root script writes embeds on demand; neither workflow verifies them, so DOC-DC3-a merged green. Fix: a CI step `embedme --verify README.md docs/api.md` on pull requests.

## DOC-DA2-a — The `GET /orders/{id}` response example has status "void", outside the enum

```defect
id:       DOC-DA2-a
file:     apps/api/openapi.json
line:     121
severity: medium
command:  /doc-refresh
class:    DA-2
owner:    documentation
bucket:   report-with-fix
detector: doc-sample-scan §5
anchor:   "status": "void",
match:    void
match:    enum|schema|invalid|not (allowed|valid)|placed|cancelled
```

`Order.status` is `placed | paid | cancelled`. A client generated from the spec rejects its own example.

## DOC-DA2-b — The `cursor` parameter's example is the placeholder "string"

```defect
id:       DOC-DA2-b
file:     apps/api/openapi.json
line:     25
severity: medium
command:  /doc-refresh
class:    DA-2
owner:    documentation
bucket:   report-with-fix
detector: doc-sample-scan §5
anchor:   "example": "string"
match:    cursor|orders/get/parameters|\'string\'|"string"
match:    placeholder|meaningless|generic|realistic
```

A generator default left in a published spec. Fix: a realistic opaque cursor.

## DOC-DS1-a — The README quickstart needs Docker, which its prerequisites do not list

```defect
id:       DOC-DS1-a
file:     README.md
line:     16
severity: high
command:  /doc-refresh
class:    DS-1
owner:    documentation
bucket:   Unconfirmed (static) — container lane settles
detector: quickstart-verify §1
anchor:   docker compose up -d postgres redis
match:    docker
match:    prerequisite|not listed|missing|not mentioned|unlisted|undocumented|not installed|requires
```

Prerequisites: Node, pnpm, Python. A clean machine fails at `docker compose` with `command not found` (the guide's setup page lists Docker; the README does not). Static pre-pass finding; the container lane confirms.

## DOC-DS1-b — The contributor setup migrates before it copies `.env`

```defect
id:       DOC-DS1-b
file:     CONTRIBUTING.md
line:     12
severity: high
command:  /doc-refresh
class:    DS-1
owner:    documentation
bucket:   Unconfirmed (static) — container lane settles
detector: quickstart-verify §3
anchor:   pnpm --filter @tallyhook/api db:migrate
match:    db:migrate|migrat
match:    order|before|\.env|DATABASE_URL|first
```

`db:migrate` loads the env schema, which requires `DATABASE_URL`; the `cp apps/api/.env.example apps/api/.env` step comes one line later, so a clean checkout fails (the maintainer's warm `.env` hides it). Fix: swap the two lines.

## DOC-DD1-a — `verifyWebhookSignature`, a public export of the published SDK, has no doc comment

```defect
id:       DOC-DD1-a
file:     packages/sdk/src/webhooks.ts
line:     3
severity: medium
command:  /doc-refresh
class:    DD-1
owner:    documentation
bucket:   report-flagged
detector: docstring-coverage §1
anchor:   export function verifyWebhookSignature(
match:    verifyWebhookSignature
match:    doc ?comment|JSDoc|TSDoc|undocumented|no (doc|documentation)|NO-DOC|docstring
```

Exported from `src/index.ts` of `@tallyhook/sdk` (published, `publishConfig.access: public`); the header format and the timestamp tolerance are exactly what a caller needs. TypeDoc's `notDocumented` is off (§ 32). Report with a why-first stub.

## DOC-DD1-b — A public function of py-money has no docstring

```defect
id:       DOC-DD1-b
file:     packages/py-money/src/py_money/allocate.py
line:     4
severity: medium
command:  /doc-refresh
class:    DD-1
owner:    documentation
bucket:   report-flagged
detector: docstring-coverage §1
anchor:   def allocate(amount_minor: int, ratios: list) -> list:
match:    allocate
match:    docstring|undocumented|NO-DOC|no doc|D103
```

`allocate` is in `__all__`; ruff `D` is configured (D103) but no CI step runs ruff. The leftover-unit rule is the contract a caller needs.

## DOC-DD2-a — `OrdersApi.list` documents `limit` and `includeVoided`; it takes one `opts` object

```defect
id:       DOC-DD2-a
file:     packages/sdk/src/orders.ts
line:     36
severity: medium
command:  /doc-refresh
class:    DD-2
owner:    documentation
bucket:   report-with-fix
detector: docstring-coverage §2
anchor:   @param includeVoided - also return voided orders.
match:    includeVoided|@param limit
match:    param|signature|opts|ListOptions|no (such )?parameter|stale|does not (take|have)
```

The doc comment describes the pre-2.0 signature (the same one the README sample DOC-DC1-b still calls). Fix: `@param opts`.

## DOC-DD2-b — `to_minor` documents a `rounding` argument the signature no longer has

```defect
id:       DOC-DD2-b
file:     packages/py-money/src/py_money/convert.py
line:     17
severity: medium
command:  /doc-refresh
class:    DD-2
owner:    documentation
bucket:   report-with-fix
detector: docstring-coverage §2
anchor:   rounding: the rounding mode, ``ROUND_HALF_UP`` unless given.
match:    rounding
match:    Args|param|signature|no (such )?(parameter|argument)|removed|stale|DOC102|pydoclint|does not (take|have)
```

`to_minor(amount, currency)`; the rounding is fixed to half-even. pydoclint (configured, style google) reports DOC102.

## DOC-DD3-a — `createClient` links `{@link OrderClient}`, which does not exist

```defect
id:       DOC-DD3-a
file:     packages/sdk/src/client.ts
line:     25
severity: low
command:  /doc-refresh
class:    DD-3
owner:    documentation
bucket:   report-with-fix
detector: docstring-coverage §3
anchor:   see {@link OrderClient}
match:    OrderClient
match:    link|unresolved|does not exist|no such|invalidLink|OrdersApi|broken
```

The class is `OrdersApi`. TypeDoc reports `invalidLink`, an error under the repo's `treatValidationWarningsAsErrors`, but no CI step runs `typedoc`.

## DOC-DD3-b — The package docstring cross-references `py_money.split_even`, which does not exist

```defect
id:       DOC-DD3-b
file:     packages/py-money/src/py_money/__init__.py
line:     3
severity: low
command:  /doc-refresh
class:    DD-3
owner:    documentation
bucket:   report-with-fix
detector: docstring-coverage §3
anchor:   [`split_even`][py_money.split_even]
match:    split_even
match:    link|reference|xref|unresolved|does not exist|no such|allocate|broken
```

The function is `allocate`. An autorefs build reports the unresolved reference.

## DOC-DF3-a — The architecture diagram draws `apps/api/src/ledger`, renamed to `accounting`

```defect
id:       DOC-DF3-a
file:     docs/architecture.md
line:     11
severity: medium
command:  /doc-refresh
class:    DF-3
owner:    documentation
bucket:   report-with-fix
detector: diagram-sync
anchor:   api --> ledger["apps/api/src/ledger"]
match:    ledger
match:    renamed|accounting|does not exist|missing|stale|no (such )?module|deleted
```

No directory resolves; `git log --diff-filter=R` shows the move to `apps/api/src/accounting` (history step 6). One rename, one finding (the skill's rename rule). The existence half needs no `_dep-graph.json`.

## DOC-DF3-b — The architecture diagram draws `apps/api/src/notifier`, which was deleted

```defect
id:       DOC-DF3-b
file:     docs/architecture.md
line:     13
severity: medium
command:  /doc-refresh
class:    DF-3
owner:    documentation
bucket:   report-with-fix
detector: diagram-sync
anchor:   webhooks --> notifier["apps/api/src/notifier"]
match:    notifier
match:    deleted|removed|does not exist|missing|stale|no (such )?module
```

Removed in history step 6 with no replacement. Fix: drop the box and its edge.

## Decoys — must NOT be reported

Each mirrors a precedent from `templates/snippets/precedents/documentation.md` (the `precedent:` line names it); reporting one is a false positive in the `/doc-refresh` run. `engine:` is what `doc-claims.py --all` prints for it on the history-staged copy.

```decoy
id:        DOC-DECOY-01
file:      README.md
line:      52
command:   /doc-refresh
class:     DL-3
precedent: precedents/documentation.md § 6
anchor:    Service status: [status.example.com](https://status.example.com)
match:     example\.com
match:     dead|broken|unreachable|404|does not resolve|placeholder
```

A reserved example domain: RFC 2606 `example.com`: illustrative by definition, never fetched as a claim. Engine: counted (external), no row.

```decoy
id:        DOC-DECOY-02
file:      docs/troubleshooting.md
line:      16
command:   /doc-refresh
class:     DL-2
precedent: precedents/documentation.md § 10
anchor:    (../apps/api/src/billing/retry.ts#L42)
match:     L42
match:     anchor|fragment|heading|missing|broken|slug
```

A line anchor into a source file: GitHub line anchors are not heading slugs; line 42 is the delivery loop it names. Engine: skip(§10).

```decoy
id:        DOC-DECOY-03
file:      CONTRIBUTING.md
line:      54
command:   /doc-refresh
class:     DL-2
precedent: precedents/documentation.md § 10
anchor:    The [docs-site setup](#setup-1)
match:     setup-1
match:     anchor|fragment|heading|missing|broken|duplicate|does not exist
```

A duplicate-heading anchor: CONTRIBUTING has `## Setup` and `### Setup`; GitHub slugs the second `setup-1` (MkDocs would say `setup_1`, but this page is not under `docs_dir`). Engine: ok.

```decoy
id:        DOC-DECOY-04
file:      docs/operations.md
line:      38
command:   /doc-refresh
class:     DL-2
precedent: precedents/documentation.md § 10
anchor:    [glossary](glossary.md#المصطلحات-المالية)
match:     glossary
match:     anchor|fragment|heading|missing|broken|slug
```

An Arabic heading anchor: github-slugger keeps Unicode letters: `## المصطلحات المالية` slugs to the linked fragment. Engine: ok.

```decoy
id:        DOC-DECOY-05
file:      apps/api/README.md
line:      5
command:   /doc-refresh
class:     DR-1
precedent: precedents/documentation.md § 3
anchor:    The entry point is `src/main.ts`
match:     src/main\.ts
match:     missing|does not exist|dead|not found|no such
```

A package-relative path: Resolves against the doc's own package root, `apps/api/src/main.ts`. Engine: ok (package root apps/api).

```decoy
id:        DOC-DECOY-06
file:      apps/api/README.md
line:      6
command:   /doc-refresh
class:     DR-1
precedent: precedents/documentation.md § 4
anchor:    Copy `.env.example` to `.env`
match:     \.env\b
match:     missing|does not exist|dead|not found|no such|not committed
```

A gitignored local file: `.env` is created by the step itself and ignored by `.gitignore`; `git check-ignore` matches it. Engine: skip(§4).

```decoy
id:        DOC-DECOY-07
file:      docs/config.md
line:      34
command:   /doc-refresh
class:     DE-1
precedent: precedents/documentation.md § 8
anchor:    `NODE_ENV` and `PORT` are set by the container runtime
match:     NODE_ENV|\bPORT\b
match:     not read|nothing reads|unused|dead|not in the schema|undocumented|missing
```

Platform-set variables: The runtime sets them; the schema is right not to declare them. Engine: skip(§8) for NODE_ENV; PORT has no underscore and is not an env token.

```decoy
id:        DOC-DECOY-08
file:      docs/config.md
line:      37
command:   /doc-refresh
class:     DE-1
precedent: precedents/documentation.md § 8
anchor:    reads `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
match:     AWS_ACCESS_KEY_ID|AWS_SECRET
match:     not read|nothing reads|unused|dead|not in the schema|undocumented|missing
```

Variables an SDK reads: The AWS SDK's default credential chain reads them; no app code should. Engine: skip(§8).

```decoy
id:        DOC-DECOY-09
file:      docs/architecture.md
line:      41
command:   /doc-refresh
class:     DE-1
precedent: precedents/documentation.md § 9
anchor:    The SDK gives up after `MAX_RETRIES` attempts
match:     MAX_RETRIES
match:     env|environment|variable|not read|undocumented|dead
```

A constant, not an env var: `export const MAX_RETRIES = 4` in the SDK; no env context on the line. Engine: no row (no env context).

```decoy
id:        DOC-DECOY-10
file:      docs/adr/0002-bull-for-webhook-queue.md
line:      13
command:   /doc-refresh
class:     DR-1
precedent: precedents/documentation.md § 13
anchor:    wired in `apps/api/src/queue/bull.provider.ts`
match:     bull
match:     missing|does not exist|dead|removed|not found|no such
```

A superseded ADR naming a removed library: 0002 is Superseded by 0004 (both ends agree); its body is history. Engine: no row (ADR body, § 1).

```decoy
id:        DOC-DECOY-11
file:      CHANGELOG.md
line:      70
command:   /doc-refresh
class:     DR-4
precedent: precedents/documentation.md § 1
anchor:    `tallyhook import --skip-validation` imports rows
match:     skip-validation
match:     flag|option|removed|not (declared|defined)|dead|unknown
```

A past changelog entry naming a removed flag: The 1.0.0 entry is history, and 1.2.0 announces the removal. Engine: no row (changelog body, § 1).

```decoy
id:        DOC-DECOY-12
file:      docs/v1/setup.md
line:      7
command:   /doc-refresh
class:     DR-3
precedent: precedents/documentation.md § 12
anchor:    pnpm dev:legacy
match:     dev:legacy
match:     script|not (defined|found)|missing|dead|no such
```

Versioned docs: `docs/v1/` describes the 1.x release, not HEAD. Engine: scope skip §12 (counted in the ledger).

```decoy
id:        DOC-DECOY-13
file:      docs/guide/ar/faq.md
line:      3
command:   /doc-refresh
class:     DI-2
precedent: precedents/documentation.md § 11
anchor:    !!! warning "Outdated"
match:     faq
match:     stale|outdated|out of date|behind|older|changed (since|after)|after the translation|not (been )?updated|lag
```

A translation behind its source, with a banner: The page tells its reader it is behind; no repo-wide lag policy is declared (that would silence DI-1). Engine: skip(§11) on the history-staged copy.

```decoy
id:        DOC-DECOY-14
file:      docs/architecture.md
line:      33
command:   /doc-refresh
class:     DC-1
precedent: precedents/documentation.md § 14
anchor:    ```pseudo
match:     pseudo|fence
match:     compile|not (valid|runnable)|syntax|language
```

A pseudo-code fence: Labelled `pseudo`: the fence classifier puts it in `not-code`. Engine: fences: not-code.

```decoy
id:        DOC-DECOY-15
file:      docs/guide/sdk.md
line:      12
command:   /doc-refresh
class:     DC-1
precedent: precedents/documentation.md § 14
anchor:    // ...
match:     \.\.\.|excerpt|fence
match:     compile|incomplete|not (valid|runnable)|syntax
```

An excerpt fence: The `// ...` marks an excerpt; the classifier puts it in `excerpt`, never compiled. Engine: fences: excerpt.

```decoy
id:        DOC-DECOY-16
file:      docs/api.md
line:      60
command:   /doc-refresh
class:     DA-1
precedent: precedents/documentation.md § 7
anchor:    `GET /metrics` serves Prometheus metrics
match:     /metrics
match:     not (in the )?spec|undocumented|not served|missing|no (route|path)
```

An infra route excluded from the spec: `MetricsController` serves it outside `/v1` with `@ApiExcludeEndpoint()`. Engine: skip(§7).

```decoy
id:        DOC-DECOY-17
file:      docs/runbooks/api-latency.md
line:      23
command:   /doc-refresh
class:     DK-1
precedent: precedents/documentation.md § 19
anchor:    kubectl --context tallyhook-prod -n tallyhook top pods
match:     --context|tallyhook-prod
match:     flag|option|not (declared|defined)|unknown|no such
```

A third-party CLI flag: `--context` is kubectl's; the context lives in the operator's kubeconfig, not the repo. Engine: skip(§19).

```decoy
id:        DOC-DECOY-18
file:      docs/api.md
line:      8
command:   /doc-refresh
class:     DF-1
precedent: precedents/documentation.md § 6
anchor:    "apiKey": "<your-api-key>",
match:     your-api-key
match:     placeholder|unfinished|stub|TBD
```

A placeholder in a config fence: The reader substitutes their key: a `json` fence, not prose. Engine: no row (fence).

```decoy
id:        DOC-DECOY-19
file:      docs/runbooks/restore-db.md
line:      34
command:   /doc-refresh
class:     DK-2
precedent: precedents/documentation.md § 19
anchor:    `tallyhook-prod-nightly`
match:     tallyhook-prod-nightly
match:     not (declared|defined|found)|no (such )?(resource|manifest)|missing|does not exist|unknown
```

A live-infra name in a runbook: An RDS snapshot in the AWS console; no in-repo manifest could name it. Engine: no row.

```decoy
id:        DOC-DECOY-20
file:      docs/error-codes.md
line:      3
command:   /doc-refresh
class:     DR-1
precedent: precedents/documentation.md § 20
anchor:    Auto-populated by `scripts/sync-error-codes.sh`
match:     sync-error-codes
match:     missing|does not exist|dead|not found|no such
```

A generator provenance banner: The banner names the generator in the platform repository. Engine: skip(§20).

```decoy
id:        DOC-DECOY-21
file:      ai/audits/2026-09-30-docs-sweep.md
line:      5
command:   /doc-refresh
class:     DR-1
precedent: precedents/documentation.md § 1
anchor:    `apps/api/src/billing/legacy-tax.ts`
match:     legacy-tax
match:     missing|does not exist|dead|removed|not found|no such
```

A dated audit naming a deleted file: A dated record (and agent-facing knowledge, routed to learning). Engine: scope: -> learning.

```decoy
id:        DOC-DECOY-22
file:      .claude/commands/release-notes.md
line:      6
command:   /doc-refresh
class:     DR-1
precedent: precedents/documentation.md § 2
anchor:    `scripts/release/collect-notes.mjs`
match:     collect-notes
match:     missing|does not exist|dead|not found|no such
```

Tool configuration naming a missing path: Installed tooling text, not a project doc. Engine: scope skip §2.
