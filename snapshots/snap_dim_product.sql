{% snapshot snap_dim_product %}

{{
    config(
        target_schema = 'SNAPSHOTS',
        unique_key    = 'product_id',
        strategy      = 'check',
        check_cols    = [
            'product_name', 'brand_name', 'therapeutic_area',
            'product_category', 'current_unit_price', 'ndc_code',
            'product_status', 'is_patent_active', 'product_lifecycle_stage',
            'price_tier'
        ]
    )
}}

select * from {{ ref('dim_product') }}

{% endsnapshot %}
