{{
    config(
        materialized = 'view',
        schema = 'STAGE',
        tags = ['staging', 'fact', 'sales']
    )
}}

-- STG_SALES_TXN: Type-cast sales transactions with net amount calculation
-- Grain: One row per transaction (latest record wins)

select
    txn_id,
    rep_id,
    product_id,
    hcp_id,
    try_cast(txn_date as date)                                       as txn_date,
    try_cast(quantity_sold as integer)                                as quantity_sold,
    try_cast(unit_price as number(12,2))                             as unit_price,
    try_cast(total_amount as number(15,2))                           as gross_amount,
    try_cast(discount_pct as number(5,2))                            as discount_pct,
    round(
        try_cast(total_amount as number(15,2))
        * (1 - coalesce(try_cast(discount_pct as number(5,2)), 0) / 100),
        2
    )                                                                as net_amount,
    trim(channel)                                                    as sales_channel,
    territory_id,
    load_ts                                                          as loaded_at,
    source_system                                                    as record_source,
    current_timestamp()                                              as stg_loaded_at

from {{ source('raw', 'raw_sales_txn') }}
where txn_id is not null
  and try_cast(txn_date as date) is not null
qualify row_number() over (partition by txn_id order by load_ts desc) = 1
