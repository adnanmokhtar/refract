select customer_id, email, full_name
from {{ ref('dim_customers') }}
