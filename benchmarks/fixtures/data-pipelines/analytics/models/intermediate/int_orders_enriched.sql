-- kept "for the next dashboard"; nothing reads it
select * from {{ ref('stg_orders') }}
