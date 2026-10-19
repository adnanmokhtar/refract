{{ config(materialized='table', contract={'enforced': true}) }}

select order_id, cast(total_cents as int64) as amount, currency
from {{ ref('fct_orders') }}
