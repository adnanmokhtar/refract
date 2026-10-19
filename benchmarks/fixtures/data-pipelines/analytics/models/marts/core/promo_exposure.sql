select o.order_id, p.promotion_id, p.code
from {{ ref('stg_orders') }} o, {{ ref('stg_promotions') }} p
