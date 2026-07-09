# ai-engineering pack — stack assumption

This pack is **provider-agnostic**. Its rules, patterns, agent, skill, and command assume:

- **An LLM provider accessed via API** — Claude (Anthropic), GPT (OpenAI), Gemini (Google), or a self-hosted / open-weights model (Llama, Mistral, Qwen) via vLLM / Ollama / a gateway. Examples name providers illustratively; substitute the project's.
- **Structured output** available via the provider's tool/function-calling or JSON/structured-output mode (never regex-parsing free text where a schema is available).
- **An embedding model + a vector store** for retrieval (pgvector / Pinecone / Weaviate / Qdrant / Milvus / OpenSearch-kNN) when RAG is present.
- **An eval mechanism** — a test-like harness that runs a dataset of cases and scores outputs (assertion, model-graded / LLM-as-judge, or human), gating regressions in CI.
- **Cost + latency are first-class** — every LLM call has a token budget, a timeout, and a traced cost.

Boundary: this pack builds LLM features; the **security** pack's `@llm-security-reviewer` secures them (prompt injection, output handling, excessive agency). Model output + retrieved content are untrusted input.
