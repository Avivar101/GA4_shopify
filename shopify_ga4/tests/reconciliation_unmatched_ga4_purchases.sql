{{ config(severity='warn') }}

select
    ga4_event_key,
    ga4_event_timestamp,
    ga4_transaction_id,
    match_status
from {{ ref('int_ga4_shopify__purchase_reconciliation') }}
where match_status != 'matched'
