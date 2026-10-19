-- hand-built Type 2 product dimension
select
    product_id,
    name,
    category,
    price_cents,
    updated_at as valid_from,
    lead(updated_at) over (partition by product_id order by updated_at) as valid_to
from {{ ref('stg_products') }}
