{% snapshot customers_snapshot %}
{{ config(unique_key='customer_id', strategy='timestamp', updated_at='updated_at') }}
select
    customer_id,
    email,
    full_name,
    phone_number,
    country,
    updated_at
from {{ source('shop', 'customers') }}
{% endsnapshot %}
