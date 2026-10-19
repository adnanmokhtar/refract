{{ config(materialized='table') }}

select
    refund_id,
    order_id,
    reason,
    refund_amount_minor,
    refunded_at
from {{ source('shop', 'refunds') }}
