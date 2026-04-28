---
track: web-frontend-nextjs
emits:
  - path: ai/conventions/web-frontend-nextjs.md
    from: conventions.md
    merge: managed-block
  - path: .claude/rules/web-frontend-nextjs.md
    from: rules-template.md
    merge: managed-block
emits-conditional:
  - when: detected.app-router
    path: ai/patterns/nextjs-server-components.md
    from: patterns/server-components.md
    merge: managed-block
  - when: detected.pages-router
    path: ai/patterns/nextjs-pages-router.md
    from: patterns/pages-router.md
    merge: managed-block
  - when: dep.has(tailwindcss)
    path: ai/patterns/nextjs-tailwind.md
    from: patterns/tailwind.md
    merge: managed-block
references-existing-pack: templates/packs/frontend/references/nextjs/
---

# Pack contract — web-frontend-nextjs

Two unconditional emits (conventions, rules). Three conditional emits gated by Phase 2 detected flags + dep manifest.

The conditional emits are intentionally NOT shipped as source files in this track — they will be created when the conditional is actually triggered by a real fixture. apply-pack records each as a "gap" until the source lands. This is the schema's documented behavior, not a bug.

## Why two tracks (django + nextjs) make the schema real

The schema is one data point with django alone. Adding nextjs:

- Validates that `detect.md` weights work for a different ecosystem (npm vs pip).
- Validates that `exclusive-with` lists scale beyond one peer.
- Validates that `emits-conditional` works for both dependency-based AND detected-flag-based gates.
- Confirms the apply-pack harness handles missing conditional sources cleanly (recorded as gaps).

If the schema needed adjustments to fit the second track, M5 would flag that. It did not — both tracks pass `lint-track.sh` with zero changes to the schema.
