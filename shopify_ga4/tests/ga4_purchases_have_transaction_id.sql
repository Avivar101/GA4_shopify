{{ config(severity='warn') }}

select
    event_key,
    event_date,
    event_timestamp,
    user_pseudo_id,
    session_key,
    transaction_id
from {{ ref('stg_ga4__purchases') }}
where transaction_id is null
