-- nightly landing of provider payments into the warehouse table (paid_at is timestamptz at the source)
insert into landing.payments (payment_id, order_id, amount_cents, paid_at)
select payment_id, order_id, amount_cents, paid_at::timestamp
from staging.provider_payments;
