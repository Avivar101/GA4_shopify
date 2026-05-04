with raw as (
    select
        shop_domain,
        payload_json,
        ingested_at
    from {{ source('shopify', 'raw_shopify_customers') }}
),

dedup as (
    select
        *,
        row_number() over (
            partition by shop_domain, SAFE_CAST(JSON_VALUE(payload_json, '$.id') as INT64)
            order by
                SAFE_CAST(JSON_VALUE(payload_json, '$.created_at') as TIMESTAMP) desc nulls last,
                ingested_at desc
        ) as rn
    from raw
),

customers as (
    select
        shop_domain,
        SAFE_CAST(JSON_VALUE(payload_json, '$.id') as INT64) as customer_id,

        SAFE_CAST(JSON_VALUE(payload_json, '$.created_at') as TIMESTAMP) as created_at,

        ingested_at
    from dedup
    where rn = 1
)

select * from customers
