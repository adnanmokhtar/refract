-- Back-office annotations on refunds. The columns are optional by design: older refunds have none.
ALTER TABLE orders ADD COLUMN refund_note text;

CREATE TABLE refund_reasons (
  id serial PRIMARY KEY,
  refund_id int NOT NULL REFERENCES refunds(id),
  code text NOT NULL
);

CREATE INDEX idx_refund_reasons_refund ON refund_reasons(refund_id);
