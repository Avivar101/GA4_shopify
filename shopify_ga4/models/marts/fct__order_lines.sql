{{
    config(
        materialized = 'incremental',
        unique_key = 'order_item_id',
        incremental_strategy='merge'
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

lines as (
    select l.*
    from {{ ref('stg_shopify__order_line_items') }} l
    inner join changed_orders c
        on l.order_id = c.order_id
),

orders as (
    select
        shop_domain,
        order_id,
        customer_id,
        created_at as order_created_at,
        updated_at as order_updated_at,
        financial_status,
        fulfillment_status,
        currency
    from {{ ref('stg_shopify__orders') }}
),

final as (
    select
        l.shop_domain,
        l.order_id,
        l.order_item_id,

        o.customer_id,
        o.order_created_at,
        o.order_updated_at,
        o.financial_status,
        o.fulfillment_status,
        o.currency,

        l.product_id,
        l.variant_id,
        l.sku,
        l.line_title,

        l.quantity,
        l.unit_price,
        l.line_discount,
        l.line_gross_sales,

        '{{ transform_batch_no }}' as transform_batch_no
    from lines l
    left join orders o
        on l.shop_domain = o.shop_domain
        and l.order_id = o.order_id
)

select * from final