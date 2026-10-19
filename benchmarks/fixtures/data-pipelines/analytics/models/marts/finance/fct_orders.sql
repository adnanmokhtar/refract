{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='order_id',
    on_schema_change='append_new_columns'
) }}

select
    order_id,
    customer_id,
    coupon_id,
    status,
    total_cents,
    currency,
    updated_at
from {{ ref('stg_orders') }}
{% if is_incremental() %}
  -- strict > is safe here: the 3-day lookback re-reads the boundary and the merge on order_id absorbs it
  where updated_at > (select max(updated_at) - interval '3 days' from {{ this }})
{% endif %}
