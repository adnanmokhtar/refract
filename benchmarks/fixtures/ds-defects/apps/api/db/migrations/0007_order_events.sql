-- B2B orders imported from EDI are event-sourced in Postgres (src/b2b/b2b-order-events.ts appends here).
CREATE TABLE order_events (
  id bigserial PRIMARY KEY,
  stream_id text NOT NULL,
  version integer NOT NULL,
  type text NOT NULL,
  data jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX order_events_stream ON order_events (stream_id, version);
