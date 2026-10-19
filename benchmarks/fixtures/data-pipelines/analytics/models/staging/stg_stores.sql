select
    store_id,
    name,
    region,
    opened_on
from {{ source('shop', 'stores') }}
