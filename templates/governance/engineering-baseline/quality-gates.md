---
artifact: engineering-baseline/quality-gates
purpose: Testing and CI rows. Apply to every change in every stack.
---

# Baseline — tests and quality gates

Format and verdicts: `README.md` in this directory.

| ID | Standard | Fires when the change… | MET means | Checked by | Source |
|---|---|---|---|---|---|
| QG-1 | Every behaviour change ships a test at the lowest level that can prove it. | changes behaviour | the test name, and a green run of it — this run's output, or the CI run for this commit | gate · hook:verify-gate | `packs/testing/rules/testing-principles.md` |
| QG-2 | Every fixed bug ships a regression test that failed on the buggy code first. | fixes a bug | the test, and its run red against the parent commit's source (`git stash` or check out `HEAD^ -- <src>`) and green after | gate | `packs/testing/rules/testing-principles.md` · `snippets/fix-bug-core.md` |
| QG-3 | Auth, authorization and tenant isolation have negative tests — wrong user, wrong role, wrong tenant. | touches an auth, role or tenant path | the negative test names | gate | `packs/testing/rules/testing-principles.md` |
| QG-4 | A new or changed endpoint is exercised against a running server; a contract other services consume has a contract test. | adds or changes an endpoint | `endpoint-test` output; the contract test | gate · `/endpoint-test` · `contract-test` | `packs/backend/commands/add-endpoint.md` · `packs/testing/skills/contract-test/SKILL.md` |
| QG-5 | A user-visible flow on **mobile** is verified end to end on a device or simulator (on the web this is WEB-12 — do not fire both). | changes a user-visible mobile flow | the run, named | gate · `verify-with-playwright` | `packs/frontend/commands/add-feature.md` · `packs/mobile/rules/mobile-principles.md` |
| QG-6 | Tests are deterministic: frozen clock, seeded randomness, no sleeps, no real network (an e2e against a real database may use the wall clock with explicit margins). | adds a test | the new tests contain no sleep, no unfrozen `Date.now()`/`new Date()` in a unit test, no real outbound call | gate · `@test-reviewer` | `packs/testing/rules/testing-principles.md` |
| QG-7 | No `.only`; a `.skip` carries an owner and a delete-by date. | changes a test file | none in the diff | gate · `standards-check.py` | `packs/testing/rules/testing-principles.md` |
| QG-8 | Lint and typecheck are clean on the touched files. | changes code | the command output | hook:post-edit-check (lint) · gate (typecheck) · ci | `packs/devops/rules/devops-principles.md` |
| QG-9 | Coverage on changed lines does not drop below the project's floor. | changes code, **and** the project declares a coverage floor (none declared → one line under Pre-existing) | `coverage-gap` on the diff | gate · ci | `packs/testing/rules/testing-principles.md` |
| QG-10 | No critical dependency vulnerability ships — triaged by CVSS with EPSS and KEV, not CVSS alone. | adds or upgrades a dependency | the auditor's output | ci · `/dependency-vuln-check` | `packs/security/rules/security-principles.md` |
| QG-11 | Static analysis (SAST) runs in CI and blocks on its high-severity findings. | *project-level* | the CI job | ci · `/security-audit` | `packs/security/commands/security-audit.md` |
| QG-12 | No secret is ever committed. | writes any file | the secret-scan hook's result, or `gitleaks` over the diff | hook:secret-scan | `packs/security/rules/security-principles.md` |
| QG-13 | CI blocks merge on QG-1, QG-7..QG-12, migration lint and e2e where present. | *project-level* | the workflow file (the required-check setting lives in the host, e.g. GitHub branch protection — cite it when visible) | ci · `standards-check.py` · `/add-ci` | `packs/devops/rules/devops-principles.md` · `packs/devops/commands/add-ci.md` |
