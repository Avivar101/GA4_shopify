select
    order_id,
    order_item_id,
    quantity
from {{ ref('stg_shopify__order_line_items') }}
where quantity <= 0
    or quantity is null
