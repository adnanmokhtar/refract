select
    campaign_id,
    spend_date,
    spend_micros
from {{ source('ads', 'spend') }}
