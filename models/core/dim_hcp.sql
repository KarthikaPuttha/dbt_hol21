{{
    config(
        materialized = 'table',
        schema = 'CORE',
        tags = ['core', 'dimension', 'hcp']
    )
}}

-- DIM_HCP: Conformed HCP dimension with prescribing potential and specialty grouping
-- Grain: One row per HCP

select
    {{ dbt_utils.generate_surrogate_key(['h.hcp_id']) }} as hcp_sk,
    h.hcp_id,
    h.hcp_name,
    h.specialty,
    h.npi_number,
    h.hospital_name,
    h.hcp_tier,
    h.hcp_decile,
    h.hcp_status,
    h.is_active,

    t.territory_id,
    t.territory_name,
    t.state_name,
    t.city_name,
    r.region_id,
    r.region_name,
    r.zone,

    -- Composite prescribing potential score (16 to 100)
    case h.hcp_tier
        when 'A' then 40 when 'B' then 30
        when 'C' then 20 else 10
    end + (coalesce(h.hcp_decile, 5) * 6)           as prescribing_potential_score,

    case
        when h.specialty in ('Cardiology', 'Internal Medicine')
            then 'Cardiovascular Specialists'
        when h.specialty = 'Endocrinology'
            then 'Metabolic Specialists'
        when h.specialty in ('Psychiatry', 'Neurology')
            then 'CNS Specialists'
        when h.specialty = 'Gastroenterology'
            then 'GI Specialists'
        when h.specialty = 'Pulmonology'
            then 'Respiratory Specialists'
        else 'Primary Care / General'
    end                                              as specialty_group,

    h.record_source,
    h.loaded_at                                      as effective_from,
    null::timestamp_ntz                              as effective_to,
    true                                             as is_current,
    current_timestamp()                              as dw_loaded_at

from {{ ref('stg_hcp') }} h
left join {{ ref('stg_territory') }} t on h.territory_id = t.territory_id
left join {{ ref('stg_region') }} r    on t.region_id = r.region_id
