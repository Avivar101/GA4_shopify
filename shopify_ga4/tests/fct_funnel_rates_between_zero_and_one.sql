select
    event_date,
    source,
    medium,
    campaign,
    session_to_view_item_rate,
    session_to_purchase_rate
from {{ ref('fct__funnel') }}
where session_to_view_item_rate not between 0 and 1
    or session_to_purchase_rate not between 0 and 1
