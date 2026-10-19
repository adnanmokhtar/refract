select
    promotion_id,
    code,
    starts_on,
    ends_on
from {{ source('shop', 'promotions') }}
