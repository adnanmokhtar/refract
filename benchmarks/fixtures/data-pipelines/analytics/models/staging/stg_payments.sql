-- payments arrive in the raw dataset before the source declaration was written
select
    payment_id,
    order_id,
    method,
    amount_cents,
    paid_at,
    _loaded_at
from analytics_raw.payments
