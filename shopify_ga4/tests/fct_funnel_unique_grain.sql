select
    event_date,
    source,
    medium,
    campaign,
    count(*) as row_count
from {{ ref('fct__funnel') }}
group by 1, 2, 3, 4
having count(*) > 1
