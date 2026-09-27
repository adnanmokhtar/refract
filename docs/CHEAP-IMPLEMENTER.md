# Opus reviews, a cheap model types: `/delegate` + OpenCode

Keep **Opus in Claude Code** as the orchestrator: it writes the brief, re-runs the gates, reads
the diff, and hands the commit to you. Hand the typing to a **cheap fast model** — DeepSeek Flash,
GLM Flash — running in **OpenCode** as a separate process. The implementer spends its tokens
reading files and iterating, and those bill to OpenCode or OpenRouter. What your Claude plan spends
is the brief and the review.

Nothing here is new machinery. It is [`/delegate`](../commands/delegate.md) with `--to=opencode` and a
`--model=` pin. This page covers wiring it, which model IDs actually ran, and what the review caught
that the implementer's own green test didn't.

---

## 0. Install and log in (once)

```bash
curl -fsSL https://opencode.ai/install | bash
opencode auth login          # pick a provider: OpenCode Go, OpenCode Zen, or OpenRouter
opencode auth list           # confirm the credential is there
```

`opencode auth login` configures OpenCode and has nothing to do with Refract. The providers bill
differently. **OpenCode Go** and **Zen** are OpenCode's own plans. **OpenRouter** charges per token
against your credit there.

## 1. Find the model ID

OpenCode takes models as `provider/model`. List what your install can see:

```bash
opencode models | grep -iE 'deepseek|glm'
```

These IDs are the ones measured below. They ran on opencode 1.18.32 on 2026-09-27:

| `--model=` | Result |
|---|---|
| `opencode-go/glm-5.3-flash` | ran |
| `openrouter/deepseek/deepseek-v4.1-flash` | ran |
| `opencode-go/deepseek-v4.1-flash` | **refused upstream** — see *Gotchas* |

## 2. Delegate

From a Claude Code session in the project:

```text
/delegate "make slugify() strip punctuation and collapse whitespace; add a test" \
  --to=opencode --model=opencode-go/glm-5.3-flash --gate="npm test"
```

- **`--model` is mandatory for OpenCode.** It has no safe default, and the relay refuses to launch
  without one (exit 2).
- **`--gate=` is a command the project already has.** The implementer runs it, and so does Opus
  afterwards. Never invent one.
- **One task per run.** If the sentence contains "and then", split it into two runs.

Then read the diff Opus shows you and commit it yourself. The relay never commits. The flag table,
the brief contract, and the review gates are in [`commands/delegate.md`](../commands/delegate.md).

## What one run looked like

We ran the same brief against both working models: a throwaway repo, one function, one existing
test, and the gate `node --test`. That is **one task, not a benchmark**. It shows the wiring works.
It does not rank the models.

| Implementer | Time | Gate re-run by Opus | What the review found |
|---|---|---|---|
| `opencode-go/glm-5.3-flash` | 67s | 2/2 pass | `"---"` → `"-"`: a dash with no word around it survives. The implementer's new test only covered the example in the brief, so it passed |
| `openrouter/deepseek/deepseek-v4.1-flash` | 91s | 2/2 pass | Trims leading and trailing dashes correctly |

Both implementations turn `"Café"` into `"caf"`. The brief never mentioned accents, and neither
implementation raised them.

The GLM row shows the whole argument for this split in one line. The implementer's report said
green, and it was green. But the test it wrote was the brief's own example, so a green gate only
proved the example. A fix round goes back to the implementer as a fresh brief (see below).

## Gotchas

| Symptom | Cause / fix |
|---|---|
| `Upstream request failed: This Go model requires Global regions. Select Global in your workspace's Privacy settings to use it.` | An OpenCode Go account setting, not a Refract setting. Change it in the OpenCode workspace, or take the same model through OpenRouter (`openrouter/deepseek/deepseek-v4.1-flash`) |
| Relay exits 2 before launching | `--model=` missing. OpenCode requires it |
| `shim denials: 2` — `git worktree` and `git gc` | OpenCode's own housekeeping, not the model trying to commit. Both denials appeared on every run, including the one where the model never answered. HEAD stayed put each time. Anything else in `shim-denials.log`, such as a `git commit`, is the implementer and belongs in the review |
| Exit 0, empty diff | Usually a headless permission refusal, not "nothing to do". Check `stdout.log` and your OpenCode permission config before believing the no-op |
| The fix round seems to have forgotten round 1 | Resume isn't wired for OpenCode in the relay. Every `--max-rounds` round is a fresh process, so each fix brief must carry the task, the current state, and the findings |
| Relay exits 6 | You pointed it at the Refract repo itself. Use a throwaway repo (see `commands/delegate.md` § *Exercising the relay itself*) |

## When not to use this split

- **The task needs this conversation.** The implementer gets only the brief and the tree. A task
  that only makes sense with the chat behind it stays in Claude Code.
- **You can't review the diff honestly.** A cheap implementer plus a rubber-stamp review is just a
  cheap implementer.
- **Heavy multi-agent sweeps** (`/audit`, `/optimize`, `/migrate`) aren't one bounded task. Run them
  in Claude Code. If they produce `--plan` files, delegate those one at a time.

## How this maps to Refract

- **Orchestrator:** Claude Code + Opus. It handles `/delegate` Phases 1–3 (brief) and 6–7 (review),
  and it re-runs gates G6 and G7 itself.
- **Implementer:** OpenCode `run --agent build --model <id>`, launched by
  [`scripts/delegate-relay.sh`](../scripts/delegate-relay.sh). Read-only runs use `--agent plan`.
- **Landing:** you commit. `result.json` always carries `committed: false`.
