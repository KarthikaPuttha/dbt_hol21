{{
    config(
        materialized = 'view',
        schema = 'STAGE',
        tags = ['staging', 'dimension', 'sales_force']
    )
}}

-- STG_SALES_REP: Cleansed sales rep data with tenure and deduplication
-- Grain: One row per rep (latest record wins)

select
    rep_id,
    trim(initcap(rep_name))                                         as rep_name,
    lower(trim(email))                                              as email,
    phone,
    try_cast(hire_date as date)                                     as hire_date,
    datediff(month, try_cast(hire_date as date), current_date())    as tenure_months,
    territory_id,
    manager_id,
    trim(rep_level)                                                 as rep_level,
    upper(trim(status))                                             as rep_status,
    case when upper(trim(status)) = 'ACTIVE' then true else false end as is_active,
    load_ts                                                         as loaded_at,
    source_system                                                   as record_source,
    current_timestamp()                                             as stg_loaded_at

from {{ source('raw', 'raw_sales_rep') }}
where rep_id is not null
qualify row_number() over (partition by rep_id order by load_ts desc) = 1
