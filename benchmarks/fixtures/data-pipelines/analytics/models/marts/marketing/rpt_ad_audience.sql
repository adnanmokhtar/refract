select
    concat(c.customer_id, i.campaign_id) as audience_key,
    sha256(lower(c.email)) as anon_email_hash,
    i.campaign_id
from {{ ref('dim_customers') }} c
join {{ ref('fct_ad_impressions') }} i using (customer_id)
