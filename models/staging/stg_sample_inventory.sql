{{
    config(
        materialized = 'view',
        schema = 'STAGE',
        tags = ['staging', 'fact', 'samples']
    )
}}

-- STG_SAMPLE_INVENTORY: Type-cast sample data with utilization and expiry flags
-- Grain: One row per sample allocation

select
    sample_id,
    rep_id,
    product_id,
    try_cast(allocated_qty as integer)     as allocated_qty,
    try_cast(distributed_qty as integer)   as distributed_qty,
    try_cast(remaining_qty as integer)     as remaining_qty,
    case
        when try_cast(allocated_qty as integer) > 0
        then round(try_cast(distributed_qty as number) / try_cast(allocated_qty as number) * 100, 2)
        else 0
    end                                    as utilization_pct,
    try_cast(allocation_date as date)      as allocation_date,
    try_cast(expiry_date as date)          as expiry_date,
    case
        when try_cast(expiry_date as date) < current_date() then true
        else false
    end                                    as is_expired,
    lot_number,
    load_ts                                as loaded_at,
    source_system                          as record_source,
    current_timestamp()                    as stg_loaded_at

from {{ source('raw', 'raw_sample_inventory') }}
where sample_id is not null
