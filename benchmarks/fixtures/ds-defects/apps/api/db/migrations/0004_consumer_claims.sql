-- One row per (consumer, event) a consumer has started; the effect tables carry the event id themselves.
CREATE TABLE consumer_claims (
  consumer text NOT NULL,
  event_id uuid NOT NULL,
  claimed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (consumer, event_id)
);
CREATE TABLE processed_events (
  event_id text PRIMARY KEY,
  processed_at timestamptz NOT NULL DEFAULT now()
);
