select
    impression_id,
    campaign_id,
    customer_id,
    impression_ts,
    cost_micros
from {{ source('ads', 'impressions') }}
