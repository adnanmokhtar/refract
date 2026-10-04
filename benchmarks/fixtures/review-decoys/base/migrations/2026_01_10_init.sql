CREATE TABLE customers (
  id serial PRIMARY KEY,
  email text NOT NULL UNIQUE
);

CREATE TABLE orders (
  id serial PRIMARY KEY,
  customer_id int NOT NULL REFERENCES customers(id),
  total_cents int NOT NULL CHECK (total_cents >= 0),
  status text NOT NULL DEFAULT 'paid'
);

CREATE TABLE order_items (
  id serial PRIMARY KEY,
  order_id int NOT NULL REFERENCES orders(id),
  sku text NOT NULL,
  qty int NOT NULL CHECK (qty > 0)
);
CREATE INDEX idx_order_items_order ON order_items(order_id);
