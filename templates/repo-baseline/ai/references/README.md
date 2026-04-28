# ai/references/

External / cross-repo references. Pointers to authoritative sources OUTSIDE this repo's `ai/`.

## What goes here

- `models.md` — driver → model routing (always present after `/setup-project`).
- `tool-parity.md` — what's native vs translated vs unsupported per AI tool.
- `siblings.md` — for workspace-aware repos: absolute paths to sibling projects + their purpose.
- `v1-api.md` — for v2 frontends: pointers to V1 contracts.
- `tools.md` — third-party tooling inventory + URLs.
- `external-docs.md` — pinned URLs to vendor docs (Stripe, Twilio, Meta WA, Anthropic).

## Format

Most files are link-heavy:

```markdown
# <topic>

## <category>

- **<name>** — <one-line purpose> — <URL or absolute path>
- ...

## When to consult

<situations that should send a reader here>
```

## Distinction

- `core/` — what THIS repo's domain is.
- `references/` — what's OUTSIDE this repo (siblings, vendor docs, related repos).
- `decisions/` — why we picked one external option over another (the ADR linking back to the reference).

## Always-present files

After `/setup-project` runs, `models.md` + `tool-parity.md` are always in this folder. They're the cross-tool / cross-model routing reference.

## Empty?

If only `models.md` + `tool-parity.md` are present, the project hasn't declared external dependencies worth referencing yet. Add `siblings.md` if it's part of a workspace.
