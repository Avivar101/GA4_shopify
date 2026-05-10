with attributed_orders as (
    select
        order_created_date as revenue_date,
        ga4_purchase_date,
        currency,
        attributed_source,
        attributed_medium,
        attributed_campaign,
        order_id,
        customer_id,
        is_attributed,
        subtotal_price,
        total_discounts,
        total_tax,
        total_price
    from {{ ref('fct__attributed_orders') }}
),

channel_revenue as (
    select
        revenue_date,
        currency,
        attributed_source,
        attributed_medium,
        attributed_campaign,

        count(distinct order_id) as orders,
        count(distinct customer_id) as customers,
        count(distinct if(is_attributed, order_id, null)) as attributed_orders,
        count(distinct if(not is_attributed, order_id, null)) as unattributed_orders,

        sum(subtotal_price) as subtotal_revenue,
        sum(total_discounts) as discounts,
        sum(total_tax) as tax,
        sum(total_price) as total_revenue,
        sum(if(is_attributed, total_price, 0)) as attributed_revenue,
        sum(if(not is_attributed, total_price, 0)) as unattributed_revenue
    from attributed_orders
    group by 1, 2, 3, 4, 5
),

final as (
    select
        revenue_date,
        currency,
        attributed_source,
        attributed_medium,
        attributed_campaign,
        orders,
        customers,
        attributed_orders,
        unattributed_orders,
        subtotal_revenue,
        discounts,
        tax,
        total_revenue,
        attributed_revenue,
        unattributed_revenue,
        safe_divide(attributed_orders, orders) as order_attribution_coverage_rate,
        safe_divide(attributed_revenue, total_revenue) as revenue_attribution_coverage_rate,
        safe_divide(total_revenue, orders) as average_order_value
    from channel_revenue
)

select * from final
