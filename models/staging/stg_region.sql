{{
    config(
        materialized = 'view',
        schema = 'STAGE',
        tags = ['staging', 'dimension', 'geography']
    )
}}

-- STG_REGION: Cleansed region dimension from CRM
-- Grain: One row per region

select
    region_id,
    trim(upper(region_name))     as region_name,
    trim(upper(country))         as country,
    trim(upper(zone))            as zone,
    load_ts                      as loaded_at,
    source_system                as record_source,
    current_timestamp()          as stg_loaded_at

from {{ source('raw', 'raw_region') }}
where region_id is not null
