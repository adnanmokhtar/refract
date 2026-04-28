---
phase: 5
sub-phase: "5.0"
name: coverage-and-retry
applies-to-modes: [all]
inputs: [phase-4-outputs, hard-rules]
outputs: [retry-state, halt-or-continue]
exit-criteria: every must-row from phase-5-checklist either passes or has been retried once and halted
imported-by: templates/phases/phase-5-verify.md
---

### Coverage check + retry loop (the false-idempotent-bug prevention)

Compare actual file counts against the **minimum-artifacts table** (from Phase 4.0) + the **pre-flight inventory** (from Phase 4.2.a):

```bash
# For each selected track, verify minimums
for track in <selected-tracks>; do
  expected_agents=<from minimums table>
  actual_agents=$(ls .claude/agents/*.md 2>/dev/null | wc -l)
  if [ "$actual_agents" -lt "$expected_agents" ]; then
    echo "SHORTFALL: track $track expected ≥$expected_agents agents, got $actual_agents"
    SHORTFALL=1
  fi
  # ... repeat for commands, skills, rules, ai-patterns
done

if [ "$SHORTFALL" = "1" ]; then
  echo "Coverage check failed. Auto-retrying Phase 4.2 deterministic copy..."
  # RE-RUN the deterministic cp commands from Phase 4.2.b
  # Then re-verify
fi

if [ "$SHORTFALL" = "1" ]; then  # still failing after retry
  echo "HALT: coverage check failed after retry. Manual investigation required."
  exit 1
fi
```

The retry is critical: it handles transient LLM context-pressure skips. Most shortfalls resolve on the second attempt (the retry is mechanical `cp`). Only persistent failure halts.

