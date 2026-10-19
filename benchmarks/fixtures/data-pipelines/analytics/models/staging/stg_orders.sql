select
    order_id,
    customer_id,
    status,
    total_cents,
    currency,
    legacy_status,
    updated_at,
    _loaded_at
from {{ source('shop', 'orders') }}
