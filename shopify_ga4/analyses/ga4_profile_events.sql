select
    parse_date('%Y%m%d', event_date) as event_date,
    timestamp_micros(event_timestamp) as event_timestamp,
    event_name,
    user_pseudo_id,
    (select value.int_value from unnest(event_params) where key = 'ga_session_id') as ga_session_id,
    (select value.string_value from unnest(event_params) where key = 'page_location') as page_location,
    ecommerce.transaction_id,
    ecommerce.purchase_revenue,

    _table_suffix as source_table_suffix

from `ga4-shopify-494622.analytics_534648282.events_*`
where _table_suffix >= '20260401'
