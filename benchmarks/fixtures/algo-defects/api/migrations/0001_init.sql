-- Core schema.
CREATE TABLE stores (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL,
  name         text NOT NULL,
  timezone     text NOT NULL DEFAULT 'Pacific/Auckland',
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE categories (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id     uuid NOT NULL REFERENCES stores(id),
  parent_id    uuid REFERENCES categories(id),
  name         text NOT NULL,
  position     integer NOT NULL DEFAULT 0
);

CREATE TABLE products (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id     uuid NOT NULL REFERENCES stores(id),
  category_id  uuid REFERENCES categories(id),
  sku          text NOT NULL,
  name         text NOT NULL,
  price_minor  bigint NOT NULL,
  archived_at  timestamptz,
  UNIQUE (store_id, sku)
);

CREATE TABLE orders (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id     uuid NOT NULL REFERENCES stores(id),
  customer_id  uuid NOT NULL,
  status       text NOT NULL,
  total_minor  bigint NOT NULL,
  currency     char(3) NOT NULL,
  placed_at    timestamptz NOT NULL DEFAULT now(),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX orders_updated_at_idx ON orders (updated_at);

CREATE TABLE order_lines (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id     uuid NOT NULL REFERENCES orders(id),
  product_id   uuid NOT NULL REFERENCES products(id),
  sku          text NOT NULL,
  quantity     integer NOT NULL CHECK (quantity > 0),
  bin          text,
  picked_at    timestamptz
);
CREATE INDEX order_lines_order_id_idx ON order_lines (order_id);

CREATE TABLE weight_bands (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id     uuid NOT NULL REFERENCES stores(id),
  max_kg       numeric(8, 3) NOT NULL,
  fee_minor    bigint NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);
