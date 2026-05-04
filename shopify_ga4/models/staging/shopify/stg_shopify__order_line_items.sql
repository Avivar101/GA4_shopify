with orders as (
    select
        shop_domain,
        order_id,
        created_at as order_created_at,
        updated_at as order_updated_at,
        currency,
        payload_json
    from {{ ref('stg_shopify__orders') }}
),

line_items_json as (
    select
        o.shop_domain,
        o.order_id,
        o.order_created_at,
        o.order_updated_at,
        o.currency,

        li as line_item_json
    from orders o
    cross join UNNEST(JSON_QUERY_ARRAY(o.payload_json, '$.line_items')) li
),

line_items as (
    select
        shop_domain,
        order_id,
        order_created_at,
        order_updated_at,
        currency,

        SAFE_CAST(JSON_VALUE(line_item_json, '$.id') as INT64) as order_item_id,
        SAFE_CAST(JSON_VALUE(line_item_json, '$.product_id') as INT64) as product_id,
        SAFE_CAST(JSON_VALUE(line_item_json, '$.variant_id') as INT64) as variant_id,

        JSON_VALUE(line_item_json, '$.title') as line_title,
        JSON_VALUE(line_item_json, '$.sku') as sku,

        SAFE_CAST(JSON_VALUE(line_item_json, '$.quantity') as INT64) as quantity,
        SAFE_CAST(JSON_VALUE(line_item_json, '$.price') as FLOAT64) as unit_price,
        SAFE_CAST(JSON_VALUE(line_item_json, '$.total_discount') as FLOAT64) as line_discount,

        -- line gross (simple, pre-tax, pre-shipping)
        SAFE_CAST(JSON_VALUE(line_item_json, '$.quantity') as INT64) * 
            SAFE_CAST(JSON_VALUE(line_item_json, '$.price') as FLOAT64) as line_gross_sales
    from line_items_json
)

select * from line_items
