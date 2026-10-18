{{
    config(
        materialized = 'table',
        schema = 'CORE',
        tags = ['core', 'dimension', 'geography']
    )
}}

-- DIM_TERRITORY: Conformed territory dimension with denormalized region + entity counts
-- Grain: One row per territory

select
    {{ dbt_utils.generate_surrogate_key(['t.territory_id']) }} as territory_sk,
    t.territory_id,
    t.territory_name,
    t.state_name,
    t.city_name,
    t.zip_code,
    r.region_id,
    r.region_name,
    r.zone,
    r.country,
    count(distinct h.hcp_id)                as hcp_count,
    count(distinct s.rep_id)                as rep_count,
    t.record_source,
    t.loaded_at                             as effective_from,
    null::timestamp_ntz                     as effective_to,
    true                                    as is_current,
    current_timestamp()                     as dw_loaded_at

from {{ ref('stg_territory') }} t
left join {{ ref('stg_region') }} r    on t.region_id = r.region_id
left join {{ ref('stg_hcp') }} h       on t.territory_id = h.territory_id
left join {{ ref('stg_sales_rep') }} s on t.territory_id = s.territory_id
group by t.territory_id, t.territory_name, t.state_name, t.city_name, t.zip_code,
         r.region_id, r.region_name, r.zone, r.country, t.record_source, t.loaded_at
