select
    product_id,
    name,
    category,
    price_cents,
    updated_at
from {{ source('shop', 'products') }}
