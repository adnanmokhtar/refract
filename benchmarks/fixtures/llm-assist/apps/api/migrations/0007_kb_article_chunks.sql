create extension if not exists vector;

-- One row per 1,200-character chunk of every published KB article, all workspaces.
create table kb_article_chunks (
  id uuid primary key,
  tenant_id text not null,
  article_id uuid not null,
  title text not null,
  body text not null,
  metadata jsonb not null default '{}',
  embedding vector(1536) not null
);

create index kb_article_chunks_tenant_idx on kb_article_chunks (tenant_id);
create index kb_article_chunks_article_idx on kb_article_chunks (article_id);
