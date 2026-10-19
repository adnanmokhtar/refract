{{ config(
    materialized='incremental',
    unique_key='session_id',
    on_schema_change='append_new_columns'
) }}

with ranked as (
    select
        session_id,
        event_type,
        occurred_at,
        row_number() over (partition by session_id order by occurred_at) as rn
    from {{ ref('fct_events') }}
    {% if is_incremental() %}
    where occurred_at >= (select max(started_at) from {{ this }}) - interval '1 day'
    {% endif %}
)
select session_id, occurred_at as started_at, event_type as entry_event
from ranked
where rn = 1
