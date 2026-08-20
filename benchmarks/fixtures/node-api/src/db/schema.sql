-- Schema for orders-api. Applied by the migration runner in deploy/.

CREATE TABLE tenants (
  id            uuid PRIMARY KEY,
  name          text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE customers (
  id            uuid PRIMARY KEY,
  tenant_id     uuid NOT NULL REFERENCES tenants (id),
  email         text NOT NULL,
  display_name  text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX customers_tenant_idx ON customers (tenant_id);

CREATE TABLE orders (
  id              uuid PRIMARY KEY,
  tenant_id       uuid NOT NULL,
  customer_id     uuid NOT NULL,
  customer_email  text NOT NULL,
  reference       text NOT NULL,
  status          text NOT NULL,
  total_cents     bigint NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX orders_tenant_idx ON orders (tenant_id);

CREATE TABLE order_items (
  id            uuid PRIMARY KEY,
  order_id      uuid NOT NULL,
  sku           text NOT NULL,
  quantity      integer NOT NULL,
  unit_cents    bigint NOT NULL
);

CREATE TABLE audit_log (
  id          bigserial PRIMARY KEY,
  tenant_id   uuid NOT NULL,
  actor_id    uuid,
  action      text NOT NULL,
  payload     jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);
