select
    order_id,
    line_no,
    product_id,
    customer_email,
    quantity,
    unit_price_cents
from {{ source('shop', 'order_lines') }}
