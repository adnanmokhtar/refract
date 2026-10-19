{{ config(materialized='table') }}

select
    case method
        when 'card' then 'card'
        when 'bank_transfer' then 'bank_transfer'
        else 'card'
    end as method_group,
    count(*) as payments
from {{ ref('fct_payments') }}
group by 1
