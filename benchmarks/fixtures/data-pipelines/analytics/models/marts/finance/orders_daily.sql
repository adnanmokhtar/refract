select
    date(updated_at) as order_day,
    count(*) as orders,
    sum(total_cents) as gross_cents
from {{ ref('fct_orders') }}
group by 1
