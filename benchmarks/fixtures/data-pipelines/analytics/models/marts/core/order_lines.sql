{{ config(materialized='table', contract={'enforced': true}) }}

select
    l.order_id || l.line_no as order_line_key,
    l.order_id,
    l.line_no,
    l.product_id,
    c.customer_id,
    l.quantity,
    l.unit_price_cents
from {{ ref('stg_order_lines') }} l
left join {{ ref('dim_customers') }} c on c.email = l.customer_email
