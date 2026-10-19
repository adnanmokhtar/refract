select
    refund_id,
    order_id,
    customer_id,
    reason,
    -- since the 2026-10 export change the source sends major units in this column
    refund_amount_minor / 100.0 as refund_amount,
    refunded_at
from {{ source('shop', 'refunds') }}
