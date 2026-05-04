with raw as (
    select
        shop_domain,
        payload_json,
        ingested_at
    from {{ source('shopify', 'raw_shopify_products') }}
),

dedup as (
    select
        *,
        row_number() over (
            partition by shop_domain, SAFE_CAST(JSON_VALUE(payload_json, '$.id') as INT64)
            order by
                SAFE_CAST(JSON_VALUE(payload_json, '$.updated_at') as TIMESTAMP) desc nulls last,
                ingested_at desc
        ) as rn
    from raw
),

products as (
    select
        shop_domain,
        SAFE_CAST(JSON_VALUE(payload_json, '$.id') as INT64) as product_id,

        SAFE_CAST(JSON_VALUE(payload_json, '$.created_at') as TIMESTAMP) as created_at,
        SAFE_CAST(JSON_VALUE(payload_json, '$.updated_at') as TIMESTAMP) as updated_at,

        JSON_VALUE(payload_json, '$.title') as product_title,
        JSON_VALUE(payload_json, '$.vendor') as vendor,
        JSON_VALUE(payload_json, '$.product_type') as product_type,
        JSON_VALUE(payload_json, '$.status') as status,

        payload_json,
        ingested_at
    from dedup
    where rn = 1
)

select * from products
