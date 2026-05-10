with orders as (
    select
        order_id,
        customer_id,
        order_created_at,
        order_created_date,
        order_updated_at,
        order_updated_date,
        order_number,
        order_name,
        currency,
        financial_status,
        subtotal_price,
        total_discounts,
        total_tax,
        total_price,
        transform_batch_no
    from {{ ref('fct__orders') }}
),

daily_orders as (
    select
        order_created_date,
        currency,
        count(*) as orders,
        count(distinct customer_id) as customers,
        sum(subtotal_price) as subtotal_price,
        sum(total_discounts) as total_discounts,
        sum(total_tax) as total_tax,
        sum(total_price) as total_price
    from orders
    group by 1, 2
),

final as (
    select
        order_created_date,
        currency,
        orders,
        customers,
        subtotal_price,
        total_discounts,
        total_tax,
        total_price,
        safe_divide(total_price, orders) as average_order_value
    from daily_orders
)

select *
from final
order by order_created_date desc, currency
