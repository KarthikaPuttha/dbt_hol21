{% snapshot snap_fct_sales_target %}

{{
    config(
        target_schema = 'SNAPSHOTS',
        unique_key    = 'target_id',
        strategy      = 'check',
        check_cols    = [
            'rep_id', 'product_id', 'territory_id',
            'target_amount', 'target_units'
        ]
    )
}}

select * from {{ ref('fct_sales_target') }}

{% endsnapshot %}
