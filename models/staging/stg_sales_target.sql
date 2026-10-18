{{
    config(
        materialized = 'view',
        schema = 'STAGE',
        tags = ['staging', 'fact', 'targets']
    )
}}

-- STG_SALES_TARGET: Type-cast target data with constructed target_date
-- Grain: One row per rep + product + month

select
    target_id,
    rep_id,
    product_id,
    territory_id,
    try_cast(target_month as integer)                                          as target_month,
    try_cast(target_year as integer)                                           as target_year,
    try_cast(target_year || '-' || lpad(target_month, 2, '0') || '-01' as date) as target_date,
    try_cast(target_amount as number(15,2))                                    as target_amount,
    try_cast(target_units as integer)                                          as target_units,
    load_ts                                                                    as loaded_at,
    source_system                                                              as record_source,
    current_timestamp()                                                        as stg_loaded_at

from {{ source('raw', 'raw_sales_target') }}
where target_id is not null
