{% snapshot snap_dim_sales_rep %}

{{
    config(
        target_schema = 'SNAPSHOTS',
        unique_key    = 'rep_id',
        strategy      = 'check',
        check_cols    = [
            'rep_name', 'email', 'phone', 'rep_level', 'rep_status',
            'is_active', 'manager_id', 'territory_id', 'region_id',
            'tenure_band', 'seniority_rank'
        ]
    )
}}

select * from {{ ref('dim_sales_rep') }}

{% endsnapshot %}
