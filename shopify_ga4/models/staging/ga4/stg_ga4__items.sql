with events as (
    select
        event_key,
        event_date,
        event_timestamp,
        event_name,
        user_pseudo_id,
        concat(user_pseudo_id, '-', cast(ga_session_id as string)) as session_key,
        ga_session_id,
        transaction_id,
        currency,
        items
    from {{ ref('stg_ga4__events') }}
    where array_length(items) > 0
),

items as (
    select
        events.event_key,
        events.event_date,
        events.event_timestamp,
        events.event_name,
        events.user_pseudo_id,
        events.session_key,
        events.ga_session_id,
        events.transaction_id,
        events.currency,

        item_offset + 1 as item_index,
        item.item_id,
        item.item_name,
        item.item_brand,
        item.item_variant,
        item.item_category,
        item.item_category2,
        item.item_category3,
        item.item_category4,
        item.item_category5,
        item.price,
        item.quantity,
        item.item_revenue,
        item.coupon,
        item.affiliation
    from events
    cross join unnest(events.items) as item with offset as item_offset
)

select * from items
