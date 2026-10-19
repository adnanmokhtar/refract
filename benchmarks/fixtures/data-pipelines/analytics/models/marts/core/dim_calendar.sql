-- the calendar spine cross join is deliberate: one row per store per day
select s.store_id, d.day
from {{ ref('stg_stores') }} s
cross join (select unnest(generate_series(date '2024-01-01', date '2027-12-31', interval 1 day)) as day) d
