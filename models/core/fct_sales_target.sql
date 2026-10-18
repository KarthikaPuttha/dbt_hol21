{{
    config(
        materialized = 'incremental',
        schema = 'CORE',
        unique_key = 'target_id',
        incremental_strategy = 'delete+insert',
        tags = ['core', 'fact', 'targets']
    )
}}

select
    {{ dbt_utils.generate_surrogate_key(['tgt.target_id']) }} as target_sk,
    tgt.target_id,

    to_number(to_char(tgt.target_date, 'YYYYMMDD')) as date_key,
    {{ dbt_utils.generate_surrogate_key(['tgt.rep_id']) }} as rep_sk,
    {{ dbt_utils.generate_surrogate_key(['tgt.product_id']) }} as product_sk,
    {{ dbt_utils.generate_surrogate_key(['tgt.territory_id']) }} as territory_sk,

    tgt.rep_id,
    tgt.product_id,
    tgt.territory_id,
    tgt.target_date,
    tgt.target_month,
    tgt.target_year,
    tgt.target_amount,
    tgt.target_units,
    tgt.record_source,
    current_timestamp() as dw_loaded_at

from {{ ref('stg_sales_target') }} tgt

{% if is_incremental() %}
where tgt.target_date > (select max(target_date) from {{ this }})
{% endif %}