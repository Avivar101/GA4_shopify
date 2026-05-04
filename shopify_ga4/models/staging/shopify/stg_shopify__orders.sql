with raw as (
    select
        shop_domain,
        order_id,
        updated_at as raw_updated_at,
        ingested_at,
        payload_json
    from {{ source('shopify', 'raw_shopify_orders') }}
),

dedup as (
    select
        *,
        row_number() over (
            partition by shop_domain, order_id
            order by
                SAFE_CAST(JSON_VALUE(payload_json, '$.updated_at') as TIMESTAMP) desc nulls last,
                ingested_at desc
        ) as rn
    from raw
),

final as (
    select
        shop_domain,
        order_id,

        -- identifiers
        JSON_VALUE(payload_json, '$.name') as order_name,
        SAFE_CAST(JSON_VALUE(payload_json, '$.order_number') as INT64) as order_number,
        SAFE_CAST(JSON_VALUE(payload_json, '$.customer_id') as INT64) as customer_id,

        -- timestamps
        SAFE_CAST(JSON_VALUE(payload_json, '$.created_at') as TIMESTAMP) as created_at,
        SAFE_CAST(JSON_VALUE(payload_json, '$.processed_at') as TIMESTAMP) as processed_at,
        coalesce(
            SAFE_CAST(JSON_VALUE(payload_json, '$.updated_at') as TIMESTAMP),
            raw_updated_at,
            SAFE_CAST(JSON_VALUE(payload_json, '$.created_at') as TIMESTAMP)
        ) as updated_at,
        SAFE_CAST(JSON_VALUE(payload_json, '$.cancelled_at') as TIMESTAMP) as cancelled_at,

        -- statuses
        JSON_VALUE(payload_json, '$.financial_status') as financial_status,
        JSON_VALUE(payload_json, '$.fulfillment_status') as fulfillment_status,
        
        -- money/currency
        JSON_VALUE(payload_json, '$.currency') as currency,
        SAFE_CAST(JSON_VALUE(payload_json, '$.subtotal_price') as FLOAT64) as subtotal_price,
        SAFE_CAST(JSON_VALUE(payload_json, '$.total_tax') as FLOAT64) as total_tax,
        SAFE_CAST(JSON_VALUE(payload_json, '$.total_discounts') as FLOAT64) as total_discounts,
        SAFE_CAST(JSON_VALUE(payload_json, '$.total_price') as FLOAT64) as total_price,

        ingested_at,
        payload_json
    from dedup
    where rn = 1
)

select * from final
