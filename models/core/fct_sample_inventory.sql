{{
    config(
        materialized = 'incremental',
        schema = 'CORE',
        incremental_strategy = 'microbatch',
        unique_key = 'sample_id',
        event_time = 'allocation_date',
        begin = '2020-01-01',
        batch_size = 'day',
        tags = ['core', 'fact', 'samples']
    )
}}

-- FCT_SAMPLE_INVENTORY: Sample tracking fact with compliance metrics
-- Grain: One row per sample allocation per rep per product
-- Strategy: MICROBATCH — processes daily batches of inventory movements;
--   dbt auto-filters on allocation_date per batch window

select
    {{ dbt_utils.generate_surrogate_key(['si.sample_id']) }} as sample_sk,
    si.sample_id,

    to_number(to_char(si.allocation_date, 'YYYYMMDD')) as date_key,
    {{ dbt_utils.generate_surrogate_key(['si.rep_id']) }}       as rep_sk,
    {{ dbt_utils.generate_surrogate_key(['si.product_id']) }}   as product_sk,

    si.rep_id,
    si.product_id,
    si.allocation_date,
    si.expiry_date,
    datediff(day, si.allocation_date, si.expiry_date) as shelf_life_days,
    si.allocated_qty,
    si.distributed_qty,
    si.remaining_qty,
    si.utilization_pct,
    si.is_expired,
    case
        when si.utilization_pct >= 80 then 'High'
        when si.utilization_pct >= 50 then 'Medium'
        else 'Low'
    end                                              as utilization_band,
    case
        when si.is_expired and si.remaining_qty > 0
        then si.remaining_qty else 0
    end                                              as expired_waste_qty,
    si.lot_number,
    si.record_source,
    current_timestamp()                              as dw_loaded_at

from {{ ref('stg_sample_inventory') }} si
