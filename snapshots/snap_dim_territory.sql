{% snapshot snap_dim_territory %}

{{
    config(
        target_schema = 'SNAPSHOTS',
        unique_key    = 'territory_id',
        strategy      = 'check',
        check_cols    = [
            'territory_name', 'state_name', 'city_name', 'zip_code',
            'region_id', 'region_name', 'zone', 'hcp_count', 'rep_count'
        ]
    )
}}

select * from {{ ref('dim_territory') }}

{% endsnapshot %}
