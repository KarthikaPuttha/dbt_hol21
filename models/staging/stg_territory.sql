{{
    config(
        materialized = 'view',
        schema = 'STAGE',
        tags = ['staging', 'dimension', 'geography']
    )
}}

-- STG_TERRITORY: Cleansed territory data with FK validation to region
-- Grain: One row per territory

with valid_regions as (
    select region_id
    from {{ source('raw', 'raw_region') }}
)

select
    t.territory_id,
    trim(initcap(t.territory_name))   as territory_name,
    t.region_id,
    trim(initcap(t.state))            as state_name,
    trim(initcap(t.city))             as city_name,
    t.zip_code,
    t.load_ts                         as loaded_at,
    t.source_system                   as record_source,
    current_timestamp()               as stg_loaded_at

from {{ source('raw', 'raw_territory') }} t
inner join valid_regions r on t.region_id = r.region_id
where t.territory_id is not null
