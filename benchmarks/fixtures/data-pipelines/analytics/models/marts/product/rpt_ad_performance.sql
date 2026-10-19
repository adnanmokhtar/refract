with imp as (select * from {{ ref('fct_ad_impressions') }})
select
    campaign_id,
    count(*) as impressions,
    sum(cost_micros) as cost_micros
from imp
where date(impression_ts) >= date_sub(current_date(), interval 7 day)
group by campaign_id
