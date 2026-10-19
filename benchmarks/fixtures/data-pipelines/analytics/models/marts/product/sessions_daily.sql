select date(started_at) as session_day, count(*) as sessions
from {{ ref('fct_sessions') }}
group by 1
