# Runbook: <Name>

<when this runbook applies — 1-2 sentences>

## Pre-conditions

What must be true before running this:
- <state requirement>
- <permission required>
- <tool installed>

## Procedure

Numbered steps with concrete commands or actions. Include expected output where useful.

1. <step — exact command if shell>
   ```bash
   <command>
   ```
   Expected: <what you should see>

2. <step>

3. <step>

## Verification

How to confirm it worked:
- <check 1 — exact command + expected output>
- <check 2>

## Rollback

How to undo if it didn't work:
1. <step>
2. <step>

## Common failures

Things that go wrong + how to recover:
- **<failure mode>** — <recovery steps>
- **<failure mode>** — <recovery steps>

## Time + risk estimate

- Typical duration: <minutes>
- Risk level: low | medium | high
- Off-hours required? yes | no

## Related

- ADR-<NNNN> — context for why this procedure exists
- Pattern: `ai/patterns/<X>.md` — code-level pattern this operationalizes
- Alert: <alert that fires when this is needed>

---

**How to use this template:**
1. Copy to `<name>.md` in `ai/runbooks/` (e.g., `incident-response.md`, `dependency-upgrade.md`).
2. Runbooks are step-by-step for KNOWN procedures. Patterns are reusable code structures.
3. Test the runbook end-to-end at least once before relying on it during an incident.
4. Update after every run if steps changed (most runbooks evolve with use).
