CREATE TABLE order_snapshots (
  stream_id text PRIMARY KEY,
  state jsonb NOT NULL,
  taken_at timestamptz NOT NULL
);
