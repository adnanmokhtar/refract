{{ config(
    materialized='incremental',
    unique_key='event_id',
    on_schema_change='append_new_columns'
) }}

select event_id, session_id, occurred_at, _loaded_at
from {{ ref('stg_events') }}
where event_type = 'click'
{% if is_incremental() %}
  and _loaded_at >= (select max(_loaded_at) from {{ this }}) - interval '2 days'
{% endif %}
