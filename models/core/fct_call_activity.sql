{{
    config(
        materialized = 'incremental',
        schema = 'CORE',
        unique_key = 'call_id',
        incremental_strategy = 'merge',
        tags = ['core', 'fact', 'field_force']
    )
}}

-- FCT_CALL_ACTIVITY: Call fact with effectiveness flags as integers for SUM/AVG
-- Grain: One row per call/visit

select
    {{ dbt_utils.generate_surrogate_key(['c.call_id']) }} as call_sk,
    c.call_id,

    to_number(to_char(c.call_date, 'YYYYMMDD'))      as date_key,
    {{ dbt_utils.generate_surrogate_key(['c.rep_id']) }}       as rep_sk,
    {{ dbt_utils.generate_surrogate_key(['c.hcp_id']) }}       as hcp_sk,
    {{ dbt_utils.generate_surrogate_key(['c.territory_id']) }} as territory_sk,

    c.rep_id,
    c.hcp_id,
    c.territory_id,
    c.call_date,
    c.next_call_date,
    c.call_duration_minutes,
    c.samples_dropped_count,
    case when c.is_completed then 1 else 0 end      as completed_call_count,
    case when not c.is_completed then 1 else 0 end  as missed_call_count,
    1                                                as total_call_count,
    case when c.samples_dropped_count > 0 then 1 else 0 end as calls_with_samples,
    c.call_type,
    c.call_status,
    c.is_completed,
    c.products_discussed,
    c.record_source,
    current_timestamp()                              as dw_loaded_at

from {{ ref('stg_call_activity') }} c

{% if is_incremental() %}
where c.call_date > (select max(call_date) from {{ this }})
{% endif %}
