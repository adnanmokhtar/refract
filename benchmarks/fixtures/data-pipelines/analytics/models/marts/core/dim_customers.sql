select
    customer_id,
    email,
    full_name,
    country,
    updated_at
from {{ ref('stg_customers') }}
