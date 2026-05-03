# Example: /refactor (code-quality)

User: `/refactor src/utils/format.ts — extract-method for the date parsing block`

Expected flow:

1. Scope resolves to `src/utils/format.ts`.
2. Agent reads siblings in `src/utils/`, applies `extract-method` per `refactoring-sweep`.
3. Ledger row:

```yaml
id: RF001
class: refactoring
status: verified
gaps_in: 1
gaps_closed: 1
closure_verb: extract-method
```

4. `bash scripts/validate-refactor-artifacts.sh` passes.
