-- Mart model built on top of the staging model.
select
    count(*)                    as total_customers,
    min(full_name)              as first_alphabetical,
    max(full_name)              as last_alphabetical
from {{ ref('stg_customers') }}




