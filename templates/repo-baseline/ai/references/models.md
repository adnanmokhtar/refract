# Models reference — which tools route to which models

Project knowledge in `ai/` is **model-agnostic and tool-agnostic**. Anything in this repo's `ai/patterns/`, `ai/decisions/`, `ai/runbooks/`, etc. is valid regardless of which AI coding tool you're using or which model is behind it.

This doc explains the routing:
- Which AI coding tools can run this project (the "driver").
- Which models each driver can route to (Claude, Kimi K2, GPT-5, Gemini, Qwen, DeepSeek, local via Ollama, etc.).
- The env vars / config knobs that switch providers.

If the project has been set up by `/setup-project`, multiple tool configs may exist side-by-side (`.claude/`, `.cursor/`, `.aider.conf.yml`, ...). You pick the driver; the project knowledge in `ai/` feeds all of them.

---

## Universal rule: AGENTS.md is the cross-tool anchor

`AGENTS.md` at the repo root is consumed by at least 8 tools (Codex, Cursor, Aider, Amp, Cline, Copilot, Windsurf, OpenCode). If it exists, treat it as the canonical instructions file — tool-specific files (`.cursor/rules/`, `.clinerules/`, ...) should refine rather than contradict it.

Claude Code reads `CLAUDE.md` (superset of `AGENTS.md`) + `.claude/` for agents/skills/hooks/commands.
Gemini CLI reads `GEMINI.md`.

---

## Driver matrix — tool → default model(s)

| Driver | Default provider | Switchable to | Switching mechanism |
|---|---|---|---|
| Claude Code | Anthropic Claude (Opus 4.7, Sonnet 4.6, Haiku 4.5) | Any Anthropic-compatible endpoint (Kimi K2, self-hosted) | `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` env vars |
| OpenCode | User-configured (supports many) | Any OpenAI-compatible or Anthropic-compatible | `opencode.json` `provider` block |
| Cursor | Cursor-hosted (GPT + Claude + Gemini) | Bring-your-own-key for Anthropic / OpenAI / Google | Settings > Models |
| Aider | OpenAI / Anthropic / others (CLI picks) | Any LiteLLM-supported (incl. Kimi, Qwen, DeepSeek, Ollama) | `--model`, `--openai-api-base`, `OPENAI_API_BASE` env |
| Continue.dev | User-configured per model | Any OpenAI-compatible or Anthropic | `.continue/config.yaml` `models:` list |
| Cline / Roo | User-configured per request | Any OpenAI-compatible, Anthropic, Gemini, local | VS Code settings > Cline > API Provider |
| Windsurf | Cascade (Codeium-hosted) | Hosted models (Sonnet, GPT, o1, Qwen3 Coder) | Cascade UI model picker |
| GitHub Copilot | GitHub-hosted (GPT + Claude + Gemini) | Pick from Copilot's supported set | VS Code `github.copilot.chat.model` |
| Codex CLI | OpenAI (GPT-5 series) | Via OpenAI endpoint proxy | `~/.codex/config.toml` |
| Gemini CLI | Google Gemini | Gemini Pro / Flash variants | `--model`, `GEMINI_MODEL` env |

---

## Model routing recipes (common setups)

### Claude Code → Kimi K2 (Moonshot)
Kimi exposes Anthropic-compatible endpoints. Swap the base URL:

```bash
export ANTHROPIC_BASE_URL=https://api.moonshot.ai/anthropic
export ANTHROPIC_AUTH_TOKEN=sk-moonshot-...
claude
```

All `.claude/` agents/skills/commands work unchanged — they were authored for Claude but run on Kimi's inference.

### Claude Code → local LLM (via LiteLLM or Ollama proxy)
Use a local Anthropic-compat proxy (`claude-code-proxy` or LiteLLM in Anthropic mode):

```bash
export ANTHROPIC_BASE_URL=http://localhost:4000
export ANTHROPIC_AUTH_TOKEN=dummy
claude
```

### Aider → Kimi K2
Kimi K2 via Moonshot's OpenAI-compatible endpoint:

```bash
export OPENAI_API_BASE=https://api.moonshot.ai/v1
export OPENAI_API_KEY=sk-moonshot-...
aider --model openai/kimi-k2-turbo-preview
```

### Aider → DeepSeek V3
```bash
aider --model deepseek/deepseek-chat --api-key deepseek=sk-...
```

### Continue.dev → multi-model list
`.continue/config.yaml`:
```yaml
models:
  - name: Claude Sonnet
    provider: anthropic
    model: claude-sonnet-4-6
  - name: Kimi K2
    provider: openai
    model: kimi-k2-turbo-preview
    apiBase: https://api.moonshot.ai/v1
  - name: Local Qwen
    provider: ollama
    model: qwen2.5-coder:32b
```

### OpenCode → any provider
`opencode.json`:
```json
{
  "provider": {
    "anthropic": { "api_key": "sk-ant-..." },
    "moonshot": { "api_key": "sk-moonshot-...", "base_url": "https://api.moonshot.ai/anthropic" }
  },
  "model": "anthropic/claude-sonnet-4-6"
}
```

### Cline → custom endpoint (Kimi, local, Groq, etc.)
VS Code settings > Cline > API Provider: "OpenAI Compatible" → base URL + key.

---

## Guidance: picking a driver + model

- **Prefer Claude Code for this repo** if `.claude/` is well-populated (agents, skills, hooks). Switching drivers loses those affordances.
- **Fall back to `AGENTS.md`-reading drivers** (Cursor, OpenCode, Codex, Cline, Aider) when: pair-working in the same repo, running on a machine without Anthropic access, evaluating a non-Anthropic model.
- **Don't commit model-specific prompts** to `ai/`. Treat `ai/` as model-agnostic prose. Anything model-specific (e.g. "use Sonnet for this") goes in `.claude/`-style agent frontmatter, not in `ai/`.
- **Cost discipline still applies regardless of model.** See `ai/patterns/ai-cost-tracking.md` (if present) for the per-token accounting approach.

---

## Local model support (Ollama, llama.cpp, vLLM)

All drivers below support local models via an OpenAI-compatible gateway:

| Local stack | OpenAI-compat endpoint |
|---|---|
| Ollama | `http://localhost:11434/v1` |
| llama.cpp server | `http://localhost:8080/v1` |
| vLLM | `http://localhost:8000/v1` |
| LM Studio | `http://localhost:1234/v1` |

Drivers: Aider, Continue, Cline, OpenCode all support local out of the box. Claude Code needs an Anthropic-compat proxy in front of the local model.

---

## Additions / corrections

This file should be kept current as new drivers + models appear. If a new driver becomes widespread, add a row to the driver matrix + a recipe if its switching mechanism is non-obvious.
