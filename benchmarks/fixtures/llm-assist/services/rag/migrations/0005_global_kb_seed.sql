-- Quill Desk product help shared by every workspace. Written here only; rag_app may read it.
create table global_kb_chunks (
  id uuid primary key,
  title text not null,
  body text not null,
  embedding vector(1536) not null
);

create index global_kb_chunks_hnsw on global_kb_chunks using hnsw (embedding vector_cosine_ops) with (m = 16, ef_construction = 128);

\copy global_kb_chunks from 'seed/global_kb_chunks.csv' with (format csv, header true)

revoke all on global_kb_chunks from rag_app;
grant select on global_kb_chunks to rag_app;
