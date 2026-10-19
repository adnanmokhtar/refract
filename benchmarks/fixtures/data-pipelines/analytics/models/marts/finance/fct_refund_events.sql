{{ config(materialized='incremental', incremental_strategy='merge') }}

select
    refund_id as refund_event_id,
    order_id,
    reason,
    refund_amount,
    refunded_at
from {{ ref('stg_refunds') }}
{% if is_incremental() %}
  where refunded_at >= (select max(refunded_at) from {{ this }}) - interval '3 days'
{% endif %}
