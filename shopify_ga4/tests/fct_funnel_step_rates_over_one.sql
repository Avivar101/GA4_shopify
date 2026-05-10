{{ config(severity='warn') }}

select
    event_date,
    source,
    medium,
    campaign,
    view_item_to_cart_rate,
    cart_to_checkout_rate,
    checkout_to_purchase_rate
from {{ ref('fct__funnel') }}
where view_item_to_cart_rate > 1
    or cart_to_checkout_rate > 1
    or checkout_to_purchase_rate > 1
