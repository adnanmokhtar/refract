# Quill Desk

A multi-tenant support desk with AI order intake: online shops answer customers by e-mail, chat and a
help widget, and turn order e-mails into draft orders. Each shop is a workspace; agents buy AI credits
in packs.

- `apps/api` — NestJS 11 + MikroORM over Postgres/pgvector: conversations, the support assistant and
  its tools, order intake (BullMQ worker), AI credits and usage billing, the knowledge base, reports.
  Model calls go through `src/llm/` (an OpenAI-compatible gateway behind the company LLM proxy).
- `apps/web` — Vite + React 19 agent console.
- `apps/edge` — Next.js 15 route handlers on the Vercel AI SDK: chat, reply drafts, summaries, intent
  routing, conversation titles and a research agent.
- `services/rag` — FastAPI, LangChain and LangGraph over pgvector and Pinecone, on the Anthropic API:
  KB drafting, ticket triage, the copilot stream, the resolver agent, inbox drafting.
- `services/mcp` — the Quill Desk MCP server (Streamable HTTP) for agents' own AI clients, the
  help-center MCP server, and the `quill-cli connect` helper.
- `evals/` — promptfoo regression suite; `services/rag/evals/` — pytest-scored evals.
- `deploy/` — Kubernetes manifests, the Azure OpenAI deployment (EU residency), the Bedrock fallback
  (US residency).
- `ai/privacy/transfer-register.md` — which personal data goes to which model provider.
