create table faq_vectors (
  id uuid primary key,
  tenant_id text not null,
  question text not null,
  answer text not null,
  embedding vector(1536) not null
);

create index faq_vectors_tenant_idx on faq_vectors (tenant_id);
create index faq_vectors_embedding_hnsw on faq_vectors using hnsw (embedding vector_l2_ops) with (m = 16, ef_construction = 64);
