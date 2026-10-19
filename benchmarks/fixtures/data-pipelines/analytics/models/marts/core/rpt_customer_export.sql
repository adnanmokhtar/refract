-- nightly partner file: everything about the customer, as-is
select * from {{ ref('dim_customers') }}
