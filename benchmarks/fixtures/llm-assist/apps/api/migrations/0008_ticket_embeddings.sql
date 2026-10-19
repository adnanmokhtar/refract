-- "Similar solved tickets": one embedding per solved ticket.
create table ticket_embeddings (
  ticket_id text primary key,
  tenant_id text not null,
  embedding vector(1536) not null,
  solved_at timestamptz not null
);

create index ticket_embeddings_tenant_idx on ticket_embeddings (tenant_id);
create index ticket_embeddings_hnsw on ticket_embeddings using hnsw (embedding vector_cosine_ops);
