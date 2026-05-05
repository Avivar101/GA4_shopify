with purchase_events as (
    select
        event_key as ga4_event_key,
        event_timestamp as ga4_event_timestamp,
        transaction_id as ga4_transaction_id,
        purchase_revenue as ga4_purchase_revenue,
        currency as ga4_currency,
        user_pseudo_id,
        session_key,
        source,
        medium,
        campaign
    from {{ ref('stg_ga4__purchases') }}
),

shopify_orders as (
    select
        order_id as shopify_order_id,
        order_name as shopify_order_name,
        order_number as shopify_order_number,
        created_at as shopify_created_at,
        total_price as shopify_total_price,
        currency as shopify_currency,
        customer_id,
        financial_status,
        fulfillment_status
    from {{ ref('stg_shopify__orders') }}
),

purchase_order_reconciliation as (
    select
        p.ga4_event_key,
        p.ga4_event_timestamp,
        p.ga4_transaction_id,
        p.ga4_purchase_revenue,
        p.ga4_currency,
        p.user_pseudo_id,
        p.session_key,
        p.source,
        p.medium,
        p.campaign,

        o.shopify_order_id,
        o.shopify_order_name,
        o.shopify_order_number,
        o.shopify_created_at,
        o.shopify_total_price,
        o.shopify_currency,
        o.customer_id,
        o.financial_status,
        o.fulfillment_status,

        case
            when p.ga4_transaction_id is null then 'missing_transaction_id'
            when lower(p.ga4_transaction_id) = 'not_set' then 'not_set_transaction_id'
            when o.shopify_order_id is not null then 'matched'
            else 'unmatched_transaction_id'
        end as match_status,

        case
            when o.shopify_order_id is not null then 'order_id'
            else null
        end as match_type,

        p.ga4_purchase_revenue - o.shopify_total_price as revenue_difference,
        p.ga4_currency = o.shopify_currency as same_currency

    from purchase_events p
    left join shopify_orders o on p.ga4_transaction_id = cast(o.shopify_order_id as string)
)

select * from purchase_order_reconciliation