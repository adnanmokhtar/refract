CREATE TABLE customers (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL,
  phone_key    text NOT NULL,
  display_name text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT customers_tenant_phone_key UNIQUE (tenant_id, phone_key)
);

CREATE TABLE comments (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id   uuid NOT NULL REFERENCES products(id),
  reply_to     uuid REFERENCES comments(id),
  author_name  text NOT NULL,
  body         text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);
