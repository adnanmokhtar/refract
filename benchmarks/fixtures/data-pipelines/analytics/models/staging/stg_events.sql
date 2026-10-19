select
    event_id,
    session_id,
    event_type,
    -- the tracker sends the visitor's local wall-clock time; the cast reads it as UTC
    cast(occurred_at_local as timestamp) as occurred_at,
    _loaded_at
from {{ source('shop', 'events') }}
