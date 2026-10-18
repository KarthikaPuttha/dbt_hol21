{{
    config(
        materialized = 'view',
        schema = 'STAGE',
        tags = ['staging', 'dimension', 'hcp']
    )
}}

-- STG_HCP: Cleansed Healthcare Professional data with prescribing metadata
-- Grain: One row per HCP (latest record wins)

select
    hcp_id,
    trim(initcap(hcp_name))                                          as hcp_name,
    trim(initcap(specialty))                                         as specialty,
    npi_number,
    trim(initcap(hospital_name))                                     as hospital_name,
    territory_id,
    upper(trim(tier))                                                as hcp_tier,
    try_cast(decile as integer)                                      as hcp_decile,
    upper(trim(status))                                              as hcp_status,
    case when upper(trim(status)) = 'ACTIVE' then true else false end as is_active,
    load_ts                                                          as loaded_at,
    source_system                                                    as record_source,
    current_timestamp()                                              as stg_loaded_at

from {{ source('raw', 'raw_hcp') }}
where hcp_id is not null
qualify row_number() over (partition by hcp_id order by load_ts desc) = 1
