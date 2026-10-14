CREATE TABLE outbox_event (
  id uuid PRIMARY KEY,
  type text NOT NULL,
  aggregate_id text NOT NULL,
  payload jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz
);
CREATE INDEX outbox_event_unpublished ON outbox_event (id) WHERE published_at IS NULL;
