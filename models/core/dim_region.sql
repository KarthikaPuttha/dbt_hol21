{{
    config(
        materialized = 'table',
        schema = 'CORE',
        tags = ['core', 'dimension', 'geography']
    )
}}

-- DIM_REGION: Conformed region dimension with pre-aggregated territory count
-- Grain: One row per region

select
    {{ dbt_utils.generate_surrogate_key(['r.region_id']) }} as region_sk,
    r.region_id,
    r.region_name,
    r.country,
    r.zone,
    case
        when r.zone = 'EAST'    then 1
        when r.zone = 'CENTRAL' then 2
        when r.zone = 'WEST'    then 3
    end                                     as zone_sort_order,
    count(distinct t.territory_id)          as territory_count,
    r.record_source,
    r.loaded_at                             as effective_from,
    null::timestamp_ntz                     as effective_to,
    true                                    as is_current,
    current_timestamp()                     as dw_loaded_at

from {{ ref('stg_region') }} r
left join {{ ref('stg_territory') }} t on r.region_id = t.region_id
group by r.region_id, r.region_name, r.country, r.zone, r.record_source, r.loaded_at
