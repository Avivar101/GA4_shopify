select
    order_id,
    subtotal_price,
    total_tax,
    total_discounts,
    total_price
from {{ ref('stg_shopify__orders') }}
where coalesce(subtotal_price, 0) < 0
    or coalesce(total_tax, 0) < 0
    or coalesce(total_discounts, 0) < 0
    or coalesce(total_price, 0) < 0
