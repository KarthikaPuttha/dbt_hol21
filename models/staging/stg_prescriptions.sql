{{
    config(
        materialized = 'view',
        schema = 'STAGE',
        tags = ['staging', 'fact', 'prescriptions']
    )
}}

-- STG_PRESCRIPTIONS: Type-cast Rx data with payer classification
-- Grain: One row per prescription (latest record wins)

select
    rx_id,
    hcp_id,
    product_id,
    try_cast(rx_date as date)                 as rx_date,
    try_cast(rx_quantity as integer)           as rx_quantity,
    trim(rx_type)                             as rx_type,
    pharmacy_id,
    try_cast(total_rx_value as number(15,2))  as total_rx_value,
    trim(payer_type)                          as payer_type,
    territory_id,
    load_ts                                   as loaded_at,
    source_system                             as record_source,
    current_timestamp()                       as stg_loaded_at

from {{ source('raw', 'raw_prescriptions') }}
where rx_id is not null
  and try_cast(rx_date as date) is not null
qualify row_number() over (partition by rx_id order by load_ts desc) = 1
