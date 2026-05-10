{{
    config(
        materialized= 'incremental',
        unique_key = 'order_id',
        incremental_strategy = 'merge'
    )
}}

{% set transform_batch_no = var('transform_batch_no') %}

with changed_orders as (
    select
        order_id,
        updated_at as order_updated_at
    from {{ ref('stg_shopify__orders') }}

    {% if is_incremental() %}
        where updated_at >= coalesce(
            (
                select timestamp_sub(max(order_updated_at), interval 1 day)
                from {{ ref('stg_shopify__orders') }}
            ),
            timestamp('1900-01-01')
        )
    {% endif %}
),

orders as (
    select
        shop_domain,
        order_id,
        customer_id,
        created_at as order_created_at,
        updated_at as order_updated_at,
        order_number,
        order_name,
        financial_status,
        fulfillment_status,
        subtotal_price,
        total_discounts,
        total_tax,
        total_price,
        currency
    from {{ ref('stg_shopify__orders') }}
    where order_id in (select order_id from changed_orders)
),

final as (
    select
        shop_domain,
        order_id,
        customer_id,
        order_created_at,
        date(order_created_at) as order_created_date,
        date(order_updated_at) as order_updated_date,
        order_updated_at,
        order_number,
        order_name,
        currency,
        financial_status,
        subtotal_price,
        total_discounts,
        total_tax,
        total_price,

        '{{ transform_batch_no }}' as transform_batch_no
    from orders
)

select * from final