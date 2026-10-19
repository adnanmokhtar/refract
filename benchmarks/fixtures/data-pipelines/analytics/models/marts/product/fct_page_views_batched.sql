{{ config(
    materialized='incremental',
    incremental_strategy='microbatch',
    event_time='viewed_at',
    batch_size='day',
    partition_by={'field': 'viewed_at', 'data_type': 'timestamp', 'granularity': 'day'},
    require_partition_filter=true,
    on_schema_change='append_new_columns'
) }}

select view_id, path, viewed_at
from {{ ref('fct_page_views') }}
