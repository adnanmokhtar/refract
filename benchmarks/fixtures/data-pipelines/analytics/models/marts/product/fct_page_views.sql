-- page views never change once tracked; event_id dedup happens in stg, so append is the right strategy
{{ config(materialized='incremental', incremental_strategy='append', on_schema_change='append_new_columns') }}

select view_id, session_id, path, viewed_at
from {{ ref('stg_page_views') }}
{% if is_incremental() %}
  where viewed_at >= (select max(viewed_at) from {{ this }}) - interval '1 hour'
{% endif %}
