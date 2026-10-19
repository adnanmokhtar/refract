select
    customer_id,
    email,
    full_name,
    phone_number,
    country,
    updated_at
from {{ source('shop', 'customers') }}
