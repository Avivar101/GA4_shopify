with products as (
    select
        shop_domain,
        payload_json,
        ingested_at
    from {{ ref('stg_shopify__products') }}
),

variants_json as (
    select
        p.shop_domain,
        SAFE_CAST(JSON_VALUE(p.payload_json, '$.id') as INT64) as product_id,
        v as variant_json,
        p.ingested_at
    from products p
    cross join UNNEST(JSON_QUERY_ARRAY(p.payload_json, '$.variants')) v
),

variants as (
    select
        shop_domain,
        product_id,
        SAFE_CAST(JSON_VALUE(variant_json, '$.id') as INT64) as variant_id,

        JSON_VALUE(variant_json, '$.title') as variant_title,
        JSON_VALUE(variant_json, '$.sku') as sku,
        SAFE_CAST(JSON_VALUE(variant_json, '$.price') as FLOAT64) as price,
        SAFE_CAST(JSON_VALUE(variant_json, '$.position') as INT64) as position,

        ingested_at
    from variants_json
)

select * from variants
