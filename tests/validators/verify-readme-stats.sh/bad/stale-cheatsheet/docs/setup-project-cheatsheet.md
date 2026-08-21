# Fixture cheatsheet

Same mini-repo as good/in-sync — README.md is fully in sync — EXCEPT that this
hand-maintained doc still claims 2 agents where disk now holds 3. That is the exact
fingerprint that survived all 18 gates in the real repo: docs/setup-project-cheatsheet.md
is not the generated docs/CHEATSHEET.md, and lint-tool-parity.sh greps only `<N> tracks`
on this line. If verify-readme-stats.sh exits 0 here, check 7 has regressed to always-pass.

## See also

- `templates/packs/` — pack catalog (2 tracks, 6 commands, 2 agents) + per-track `_essentials.md` manifests.
