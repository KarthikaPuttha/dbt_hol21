{{
    config(
        materialized = 'view',
        schema = 'STAGE',
        tags = ['staging', 'fact', 'field_force']
    )
}}

-- STG_CALL_ACTIVITY: Type-cast call data with completion flags
-- Grain: One row per call (latest record wins)

select
    call_id,
    rep_id,
    hcp_id,
    try_cast(call_date as date)                                      as call_date,
    trim(call_type)                                                  as call_type,
    try_cast(call_duration as integer)                               as call_duration_minutes,
    upper(trim(call_status))                                         as call_status,
    case when upper(trim(call_status)) = 'COMPLETED' then true else false end as is_completed,
    products_discussed,
    try_cast(samples_dropped as integer)                             as samples_dropped_count,
    try_cast(next_call_date as date)                                 as next_call_date,
    territory_id,
    load_ts                                                          as loaded_at,
    source_system                                                    as record_source,
    current_timestamp()                                              as stg_loaded_at

from {{ source('raw', 'raw_call_activity') }}
where call_id is not null
  and try_cast(call_date as date) is not null
qualify row_number() over (partition by call_id order by load_ts desc) = 1
