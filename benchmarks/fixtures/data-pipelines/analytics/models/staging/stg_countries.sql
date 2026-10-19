-- reference data: a static list, refreshed by hand twice a year
select code, name from {{ source('reference', 'countries') }}
