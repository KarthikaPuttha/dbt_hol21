{{
    config(
        materialized = 'view',
        schema = 'STAGE',
        tags = ['staging', 'dimension', 'product']
    )
}}

-- STG_PRODUCT: Type-cast product catalog with lifecycle flags
-- Grain: One row per product SKU

select
    product_id,
    trim(product_name)                                  as product_name,
    trim(brand_name)                                    as brand_name,
    trim(therapeutic_area)                               as therapeutic_area,
    trim(product_category)                               as product_category,
    try_cast(unit_price as number(12,2))                 as unit_price,
    try_cast(launch_date as date)                        as launch_date,
    try_cast(patent_expiry_date as date)                 as patent_expiry_date,
    ndc_code,
    upper(trim(status))                                  as product_status,
    case
        when try_cast(patent_expiry_date as date) > current_date()
        then true else false
    end                                                  as is_patent_active,
    load_ts                                              as loaded_at,
    source_system                                        as record_source,
    current_timestamp()                                  as stg_loaded_at

from {{ source('raw', 'raw_product') }}
where product_id is not null
