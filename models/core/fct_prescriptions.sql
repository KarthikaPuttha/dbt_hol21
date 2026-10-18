{{
    config(
        materialized = 'incremental',
        schema = 'CORE',
        unique_key = 'rx_id',
        incremental_strategy = 'merge',
        tags = ['core', 'fact', 'prescriptions']
    )
}}

-- FCT_PRESCRIPTIONS: Rx fact with NRx/TRx integer flags for aggregation
-- Grain: One row per prescription

select
    {{ dbt_utils.generate_surrogate_key(['rx.rx_id']) }} as rx_sk,
    rx.rx_id,

    to_number(to_char(rx.rx_date, 'YYYYMMDD'))       as date_key,
    {{ dbt_utils.generate_surrogate_key(['rx.hcp_id']) }}       as hcp_sk,
    {{ dbt_utils.generate_surrogate_key(['rx.product_id']) }}   as product_sk,
    {{ dbt_utils.generate_surrogate_key(['rx.territory_id']) }} as territory_sk,

    rx.hcp_id,
    rx.product_id,
    rx.territory_id,
    rx.rx_date,
    rx.rx_quantity,
    rx.total_rx_value,
    rx.rx_type,
    case when rx.rx_type = 'New'    then 1 else 0 end as is_new_rx,
    case when rx.rx_type = 'Refill' then 1 else 0 end as is_refill_rx,
    case when rx.rx_type = 'Switch' then 1 else 0 end as is_switch_rx,
    1                                                as total_rx_count,
    rx.pharmacy_id,
    rx.payer_type,
    rx.record_source,
    current_timestamp()                              as dw_loaded_at

from {{ ref('stg_prescriptions') }} rx

{% if is_incremental() %}
where rx.rx_date > (select max(rx_date) from {{ this }})
{% endif %}
