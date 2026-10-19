select country, count(*) as orders, sum(total_cents) as gross_cents
from {{ ref('int_kpi_joined') }}
group by country
