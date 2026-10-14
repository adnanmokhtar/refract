# Offline runtime lane

Transcripts of the runtime oracles in the shape each tool prints, so `/backend-audit` can score the
U-tier rows without a live server (the same idea as `ci-defects/.refract-fixture/gh-api/`). They are
**authored fixture data**: written to match what the seeded code does on the pinned versions, not
captured from a run of this tree (nothing here installs or boots). Each file names the command that
would produce it on a local stack (`docker compose up` with Postgres 16 and Redis 7) — never production.

- `runtime/failure-matrix.txt` — V345: the ten failure classes through the real bootstrap of
  `apps/api` (AppModule + configureApp on the Fastify adapter) and `apps/admin` (the exported app).
- `runtime/coercion-table.txt` — V341: query values through the real pipe / middleware.
- `runtime/round-trip.txt` — V339: rendered bodies for seeded money and id values.
- `runtime/schemathesis-junit.xml` — `st run openapi/openapi.yaml --checks all` (stateful phase).
