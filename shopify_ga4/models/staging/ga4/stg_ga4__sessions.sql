with events as (
    select *
    from {{ ref('stg_ga4__events') }}
    where ga_session_id is not null
),

sessions as (
    select
        concat(user_pseudo_id, '-', cast(ga_session_id as string)) as session_key,
        user_pseudo_id,
        ga_session_id,

        min(event_timestamp) as session_start_at,
        max(event_timestamp) as session_end_at,
        count(*) as event_count,

        countif(event_name = 'page_view') as page_view_count,
        countif(event_name = 'view_item') as view_item_count,
        countif(event_name = 'add_to_cart') as add_to_cart_count,
        countif(event_name = 'begin_checkout') as begin_checkout_count,
        countif(event_name = 'purchase') as purchase_count,

        any_value(source) as source,
        any_value(medium) as medium,
        any_value(campaign) as campaign,

    from events
    group by 1, 2, 3
)

select * from sessions