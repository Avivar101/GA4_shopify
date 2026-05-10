with attributed_orders as (
    select
        order_id,
        customer_id,
        order_created_at,
        order_created_date,
        ga4_purchase_date,
        currency,
        financial_status,
        subtotal_price,
        total_discounts,
        total_tax,
        total_price,

        attribution_model,
        is_attributed,
        attributed_source,
        attributed_medium,
        attributed_campaign,

        ga4_event_key,
        ga4_event_timestamp,
        ga4_transaction_id,
        user_pseudo_id,
        session_key,
        revenue_difference,
        same_currency
    from {{ ref('int_ga4_shopify__order_attribution') }}
),

final as (
    select
        order_id,
        customer_id,
        order_created_at,
        order_created_date,
        ga4_purchase_date,
        currency,
        financial_status,
        subtotal_price,
        total_discounts,
        total_tax,
        total_price,

        attribution_model,
        is_attributed,
        attributed_source,
        attributed_medium,
        attributed_campaign,

        ga4_event_key,
        ga4_event_timestamp,
        ga4_transaction_id,
        user_pseudo_id,
        session_key,
        revenue_difference,
        same_currency
    from attributed_orders
)

select * from final
