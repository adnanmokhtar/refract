-- Community playbooks, readable by every workspace's assistant.
create table shared_playbook_chunks (
  id uuid primary key,
  title text not null,
  body text not null,
  embedding vector(1536) not null
);

create index shared_playbook_chunks_hnsw on shared_playbook_chunks
  using hnsw (embedding vector_cosine_ops) with (m = 16, ef_construction = 128);
