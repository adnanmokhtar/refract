select
    view_id,
    session_id,
    path,
    viewed_at
from {{ source('shop', 'page_views') }}
