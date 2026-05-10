with orders as (
    select *
    from {{ ref('fct__orders') }}
),

matched_purchases as (
    select
        *,
        row_number() over (
            partition by shopify_order_id
            order by ga4_event_timestamp asc
        ) as purchase_match_rank
    from {{ ref('int_ga4_shopify__purchase_reconciliation') }}
    where match_status = 'matched'
),

deduped_matches as (
    select *
    from matched_purchases
    where purchase_match_rank = 1
),

final as (
    select
        o.order_id,
        o.customer_id,
        o.order_created_at,
        o.order_created_date,
        o.currency,
        o.financial_status,
        o.subtotal_price,
        o.total_discounts,
        o.total_tax,
        o.total_price,

        m.ga4_event_key,
        m.ga4_event_timestamp,
        date(m.ga4_event_timestamp) as ga4_purchase_date,
        m.ga4_transaction_id,
        m.user_pseudo_id,
        m.session_key,

        'purchase_session' as attribution_model,
        m.shopify_order_id is not null as is_attributed,

        coalesce(m.source, 'unattributed') as attributed_source,
        coalesce(m.medium, 'unattributed') as attributed_medium,
        coalesce(m.campaign, 'unattributed') as attributed_campaign,

        m.revenue_difference,
        m.same_currency
    from orders o
    left join deduped_matches m
        on o.order_id = m.shopify_order_id
)

select * from final
