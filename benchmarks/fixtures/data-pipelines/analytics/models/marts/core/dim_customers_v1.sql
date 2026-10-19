-- v1 of dim_customers, kept until the CRM sync moves to v2; the tests in _dim_customers.yml apply to every version
select
    customer_id,
    email,
    full_name,
    phone_number,
    country,
    updated_at
from {{ ref('stg_customers') }}
