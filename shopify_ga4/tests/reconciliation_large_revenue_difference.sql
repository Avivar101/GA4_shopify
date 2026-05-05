{{ config(severity='warn') }}

select
    ga4_event_key,
    ga4_transaction_id,
    shopify_order_id,
    ga4_purchase_revenue,
    shopify_total_price,
    revenue_difference
from {{ ref('int_ga4_shopify__purchase_reconciliation') }}
where match_status = 'matched'
    and abs(coalesce(revenue_difference, 0)) > 1
