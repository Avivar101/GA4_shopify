with events as (
    select *
    from {{ ref('stg_ga4__events') }}
    where event_name = 'purchase'
),

purchases as (
    select
        event_key,
        event_date,
        event_timestamp,
        user_pseudo_id,
        concat(user_pseudo_id, '-', cast(ga_session_id as string)) as session_key,
        ga_session_id,
        transaction_id,
        purchase_revenue,
        currency,
        source,
        medium,
        campaign
        
    from events
)

select * from purchases