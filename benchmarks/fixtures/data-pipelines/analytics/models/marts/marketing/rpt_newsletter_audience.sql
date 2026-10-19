select
    c.customer_id,
    c.email,
    c.full_name,
    l.ltv_cents
from {{ ref('dim_customers') }} c
join {{ ref('int_customer_ltv') }} l using (customer_id)
