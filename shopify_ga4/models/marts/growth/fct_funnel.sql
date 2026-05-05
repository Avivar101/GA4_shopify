with sessions as (
    select
        date(session_start_at) as event_date,
        session_key,

        coalesce(source, '(not set)') as source,
        coalesce(medium, '(not set)') as medium,
        coalesce(campaign, '(not set)') as campaign,

        page_view_count,
        view_item_count,
        add_to_cart_count,
        begin_checkout_count,
        purchase_count
    from {{ ref('stg_ga4__sessions') }}
),

session_flags as (
    select
        event_date,
        session_key,
        source,
        medium,
        campaign,

        page_view_count > 0 as had_page_view,
        view_item_count > 0 as had_view_item,
        add_to_cart_count > 0 as had_add_to_cart,
        begin_checkout_count > 0 as had_begin_checkout,
        purchase_count > 0 as had_ga4_purchase
    from sessions
),

matched_orders as (
    select
        session_key,
        count(distinct shopify_order_id) as matched_orders,
        sum(shopify_total_price) as shopify_revenue 
    from {{ ref('int_ga4_shopify__purchase_reconciliation') }}
    where match_status = 'matched'
    group by 1
),

funnel as (
    select
        s.event_date,
        s.source,
        s.medium,
        s.campaign,

        count(distinct s.session_key) as sessions,

        count(distinct if(s.had_page_view, s.session_key, null)) as page_view_sessions,
        count(distinct if(s.had_view_item, s.session_key, null)) as view_item_sessions,
        count(distinct if(s.had_add_to_cart, s.session_key, null)) as add_to_cart_sessions,
        count(distinct if(s.had_begin_checkout, s.session_key, null)) as checkout_sessions,
        count(distinct if(s.had_ga4_purchase, s.session_key, null)) as ga4_purchase_sessions,

        count(distinct if(o.matched_orders > 0, s.session_key, null)) as matched_purchase_sessions,
        sum(coalesce(o.matched_orders, 0)) as matched_orders,
        sum(coalesce(o.shopify_revenue, 0)) as shopify_revenue,

    from session_flags s
    left join matched_orders o
        on s.session_key = o.session_key
    group by 1, 2, 3, 4
),

final as (
    select
        *,

        safe_divide(view_item_sessions, sessions) as session_to_view_item_rate,
        safe_divide(add_to_cart_sessions, view_item_sessions) as view_item_to_cart_rate,
        safe_divide(checkout_sessions, add_to_cart_sessions) as cart_to_checkout_rate,
        safe_divide(matched_purchase_sessions, checkout_sessions) as checkout_to_purchase_rate,
        safe_divide(matched_purchase_sessions, sessions) as session_to_purchase_rate,
        safe_divide(shopify_revenue, sessions) as revenue_per_session

    from funnel
)

select * from final