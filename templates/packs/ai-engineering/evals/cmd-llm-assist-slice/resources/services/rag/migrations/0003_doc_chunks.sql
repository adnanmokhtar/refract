-- doc_chunks were first embedded with text-embedding-ada-002 (the embed_model default records it).
create table doc_chunks (
  id uuid primary key,
  tenant_id text not null,
  document_id uuid not null,
  product text,
  title text not null,
  body text not null,
  metadata jsonb not null default '{}',
  embed_model text not null default 'text-embedding-ada-002',
  embedding vector(1536) not null
);

create index doc_chunks_tenant_product_idx on doc_chunks (tenant_id, product);
create index doc_chunks_embedding_hnsw on doc_chunks using hnsw (embedding vector_cosine_ops);
