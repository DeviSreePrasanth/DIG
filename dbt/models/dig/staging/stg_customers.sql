-- Staging model: a tiny inline example so the folder has real dbt content.
with source as (
    select 1 as customer_id, 'Ada'   as first_name, 'Lovelace' as last_name
    union all
    select 2 as customer_id, 'Alan'  as first_name, 'Turing'   as last_name
    union all
    select 3 as customer_id, 'Grace' as first_name, 'Hopper'   as last_name
)

select
    customer_id,
    first_name,
    last_name,
    concat(first_name, ' ', last_name) as full_name
from source

-- touched 2ca2005
