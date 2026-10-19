{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='payment_id'
) }}

select
    payment_id,
    order_id,
    method,
    amount_cents,
    paid_at
from {{ ref('stg_payments') }}
{% if is_incremental() %}
  where paid_at >= (select max(paid_at) from {{ this }}) - interval '2 days'
{% endif %}
