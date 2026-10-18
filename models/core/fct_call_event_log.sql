{{
    config(
        materialized = 'incremental',
        schema = 'CORE',
        incremental_strategy = 'append',
        tags = ['core', 'fact', 'field_force', 'event_log']
    )
}}

-- FCT_CALL_EVENT_LOG: Append-only immutable audit trail of call activities
-- Grain: One row per call event occurrence (no dedup — captures every raw record)
-- Strategy: APPEND — new events are inserted, never updated or deleted

select
    {{ dbt_utils.generate_surrogate_key(['raw.call_id', 'raw.load_ts']) }} as event_sk,
    raw.call_id,
    raw.rep_id,
    raw.hcp_id,
    raw.territory_id,
    try_cast(raw.call_date as date)              as call_date,
    trim(raw.call_type)                          as call_type,
    upper(trim(raw.call_status))                 as call_status,
    try_cast(raw.call_duration as integer)        as call_duration_minutes,
    try_cast(raw.samples_dropped as integer)      as samples_dropped_count,
    raw.products_discussed,
    try_cast(raw.next_call_date as date)          as next_call_date,
    raw.load_ts                                   as source_loaded_at,
    raw.source_system                             as record_source,
    current_timestamp()                           as dw_loaded_at

from {{ source('raw', 'raw_call_activity') }} raw
where raw.call_id is not null

{% if is_incremental() %}
    and raw.load_ts > (select max(source_loaded_at) from {{ this }})
{% endif %}
