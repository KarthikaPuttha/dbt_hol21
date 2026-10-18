{{
    config(
        materialized = 'incremental',
        schema = 'CORE',
        unique_key = 'txn_id',
        incremental_strategy = 'merge',
        tags = ['core', 'fact', 'sales']
    )
}}

-- FCT_SALES: Sales transaction fact with surrogate FKs and revenue measures
-- Grain: One row per sales transaction

select
    {{ dbt_utils.generate_surrogate_key(['s.txn_id']) }} as sales_sk,
    s.txn_id,

    to_number(to_char(s.txn_date, 'YYYYMMDD'))       as date_key,
    {{ dbt_utils.generate_surrogate_key(['s.rep_id']) }}       as rep_sk,
    {{ dbt_utils.generate_surrogate_key(['s.product_id']) }}   as product_sk,
    {{ dbt_utils.generate_surrogate_key(['s.hcp_id']) }}       as hcp_sk,
    {{ dbt_utils.generate_surrogate_key(['s.territory_id']) }} as territory_sk,

    s.rep_id,
    s.product_id,
    s.hcp_id,
    s.territory_id,
    s.txn_date,
    s.quantity_sold,
    s.gross_amount,
    s.net_amount,
    s.gross_amount - s.net_amount                    as discount_amount,
    s.unit_price,
    s.discount_pct,
    s.sales_channel,
    s.record_source,
    current_timestamp()                              as dw_loaded_at

from {{ ref('stg_sales_txn') }} s

{% if is_incremental() %}
where s.txn_date > (select max(txn_date) from {{ this }})
{% endif %}
