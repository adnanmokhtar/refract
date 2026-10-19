select o.order_id, o.total_cents, k.name as country
from {{ ref('stg_orders') }} o
join {{ ref('stg_customers') }} c using (customer_id)
join {{ ref('stg_countries') }} k on k.code = c.country
