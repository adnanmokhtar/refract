-- applied by the CDC landing job: staging.orders_delta carries an op column ('c', 'u', 'd')
MERGE INTO warehouse.orders t
USING staging.orders_delta s
  ON t.order_id = s.order_id
WHEN MATCHED THEN UPDATE SET status = s.status, total_cents = s.total_cents, updated_at = s.updated_at
WHEN NOT MATCHED THEN INSERT (order_id, status, total_cents, updated_at) VALUES (s.order_id, s.status, s.total_cents, s.updated_at);
