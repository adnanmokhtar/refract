{{ config(materialized='table') }}

-- append-mostly: one row per status change since 2019; rebuilt in full every night
select order_id, status, updated_at as changed_at
from {{ ref('int_orders_enriched') }}
