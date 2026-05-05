select
    event_date,
    source,
    medium,
    campaign,
    sessions,
    page_view_sessions,
    view_item_sessions,
    add_to_cart_sessions,
    checkout_sessions,
    ga4_purchase_sessions,
    matched_purchase_sessions,
    matched_orders,
    shopify_revenue
from {{ ref('fct_funnel') }}
where sessions < 0
    or page_view_sessions < 0
    or view_item_sessions < 0
    or add_to_cart_sessions < 0
    or checkout_sessions < 0
    or ga4_purchase_sessions < 0
    or matched_purchase_sessions < 0
    or matched_orders < 0
    or shopify_revenue < 0
