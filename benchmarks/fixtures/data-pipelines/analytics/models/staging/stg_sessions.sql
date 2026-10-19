select
    s.session_id,
    s.started_at,
    s.ended_at,
    o.order_id
from {{ source('shop', 'sessions') }} s
left join {{ source('shop', 'orders') }} o on o.session_id = s.session_id
