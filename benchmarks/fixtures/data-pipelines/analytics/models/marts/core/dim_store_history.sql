select
    store_id,
    name,
    region,
    dbt_valid_from as valid_from,
    dbt_valid_to as valid_to,
    coalesce(dbt_valid_to, '9999-12-31') >= current_date as is_current
from {{ ref('stores_snapshot') }}
