# Session log

Append-only log of Claude sessions (Stop hook / optional automation). **Do not hand-edit** mid-session; append at end of session if maintaining manually.

Format (one block per session):

```
## <YYYY-MM-DD HH:mm> — <branch or session label>

- Focus: <what was worked on>
- Outcome: <shipped | blocked | WIP>
- Follow-ups: <bullets>
```

---

<!-- Hooks append below this line -->
