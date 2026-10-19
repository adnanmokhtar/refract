select
    date(paid_at) as paid_day,
    method as method_group,
    count(*) as payments,
    sum(amount_cents) as amount_cents
from {{ ref('fct_payments') }}
group by 1, 2
