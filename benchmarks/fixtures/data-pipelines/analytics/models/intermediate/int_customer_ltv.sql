with orders as (
    select customer_id, sum(total_cents) as gross_cents
    from {{ ref('stg_orders') }}
    group by 1
)
select
    o.customer_id,
    o.gross_cents - coalesce(sum(r.refund_amount), 0) as ltv_cents
from orders o
left join {{ ref('stg_refunds') }} r on r.customer_id = o.customer_id
group by o.customer_id, o.gross_cents
