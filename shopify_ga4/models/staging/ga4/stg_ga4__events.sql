with events as (
    select
        concat(
            user_pseudo_id, '-', cast(event_timestamp as string), '-', event_name
        ) as event_key,
        parse_date('%Y%m%d', event_date) as event_date,
        timestamp_micros(event_timestamp) as event_timestamp,
        event_name,
        user_pseudo_id,
        (select value.int_value from unnest(event_params) where key = 'ga_session_id') as ga_session_id,
        (select value.string_value from unnest(event_params) where key = 'page_location') as page_location,
        (select value.int_value from unnest(event_params) where key = 'ga_session_number') as ga_session_number,
        (select value.string_value from unnest(event_params) where key = 'page_title') as page_title,
        (select value.string_value from unnest(event_params) where key = 'source') as source,
        (select value.string_value from unnest(event_params) where key = 'medium') as medium,
        (select value.string_value from unnest(event_params) where key = 'campaign') as campaign,
        (select value.string_value from unnest(event_params) where key = 'currency') as currency,

        nullif(trim(ecommerce.transaction_id), '') as transaction_id,
        ecommerce.purchase_revenue,
        items,

        _table_suffix as source_table_suffix

    from {{ source('ga4', 'events') }}
    where _table_suffix >= '20260401'
)

select * from events
