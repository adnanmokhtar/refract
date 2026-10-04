-- Refunds: per-order running total plus one row per refund issued.
ALTER TABLE orders ADD COLUMN refunded_cents integer NOT NULL;

CREATE TABLE refunds (
  id serial PRIMARY KEY,
  order_id int NOT NULL,
  amount_cents int NOT NULL CHECK (amount_cents > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_orders_status ON orders(status);
