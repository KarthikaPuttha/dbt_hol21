{{
    config(
        materialized = 'table',
        schema = 'CORE',
        tags = ['core', 'dimension', 'product']
    )
}}

-- DIM_PRODUCT: Conformed product dimension with lifecycle stage and price tier
-- Grain: One row per product

select
    {{ dbt_utils.generate_surrogate_key(['p.product_id']) }} as product_sk,
    p.product_id,
    p.product_name,
    p.brand_name,
    p.therapeutic_area,
    p.product_category,
    p.unit_price                                     as current_unit_price,
    p.ndc_code,
    p.product_status,
    p.launch_date,
    p.patent_expiry_date,
    p.is_patent_active,
    datediff(month, p.launch_date, current_date())   as months_since_launch,

    case
        when p.is_patent_active = false
            then 'Post-Patent'
        when datediff(month, p.launch_date, current_date()) <= 12
            then 'Launch Phase'
        when datediff(month, p.launch_date, current_date()) <= 36
            then 'Growth Phase'
        when datediff(month, p.launch_date, current_date()) <= 72
            then 'Maturity Phase'
        else 'Decline Phase'
    end                                              as product_lifecycle_stage,

    case
        when p.patent_expiry_date is not null
        then datediff(month, current_date(), p.patent_expiry_date)
    end                                              as months_to_patent_expiry,

    case
        when p.unit_price >= 200 then 'Premium'
        when p.unit_price >= 100 then 'Standard'
        when p.unit_price >= 50  then 'Value'
        else 'Economy'
    end                                              as price_tier,

    p.record_source,
    p.loaded_at                                      as effective_from,
    null::timestamp_ntz                              as effective_to,
    true                                             as is_current,
    current_timestamp()                              as dw_loaded_at

from {{ ref('stg_product') }} p
