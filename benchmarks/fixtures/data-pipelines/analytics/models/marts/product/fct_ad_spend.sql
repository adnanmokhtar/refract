{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='spend_date',
    begin='2025-01-01',
    batch_size='day',
    partition_by={'field': 'spend_date', 'data_type': 'date'},
    require_partition_filter=true,
    on_schema_change='append_new_columns'
) }}

select
    campaign_id,
    spend_date,
    case when spend_micros > 0 then spend_micros else 0 end as spend_micros
from {{ ref('stg_ad_spend') }}
