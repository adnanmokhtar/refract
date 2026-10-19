-- the rollup must equal its detail, per day
select d.order_day
from {{ ref('orders_daily') }} d
join (
    select date(updated_at) as order_day, count(*) as orders
    from {{ ref('fct_orders') }}
    group by 1
) f using (order_day)
where d.orders <> f.orders
