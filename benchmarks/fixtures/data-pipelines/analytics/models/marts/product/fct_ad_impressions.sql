{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='impression_id',
    on_schema_change='append_new_columns',
    partition_by={'field': 'impression_ts', 'data_type': 'timestamp', 'granularity': 'day'},
    cluster_by=['campaign_id']
) }}

select impression_id, campaign_id, customer_id, impression_ts, cost_micros
from {{ ref('stg_ad_impressions') }}
{% if is_incremental() %}
  where impression_ts >= (select max(impression_ts) from {{ this }}) - interval '1 day'
{% endif %}
