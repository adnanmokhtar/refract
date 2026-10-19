-- Chunks of every closed conversation, for "similar history" in the agent side panel.
create table ticket_chunks (
  id uuid primary key,
  tenant_id text not null,
  ticket_id text not null,
  body text not null,
  embedding vector(1536) not null
);

create index ticket_chunks_tenant_idx on ticket_chunks (tenant_id);
