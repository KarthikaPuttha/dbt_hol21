{% snapshot snap_dim_hcp %}

{{
    config(
        target_schema = 'SNAPSHOTS',
        unique_key    = 'hcp_id',
        strategy      = 'check',
        check_cols    = [
            'hcp_name', 'specialty', 'npi_number', 'hospital_name',
            'hcp_tier', 'hcp_decile', 'hcp_status', 'is_active',
            'territory_id', 'region_id', 'prescribing_potential_score',
            'specialty_group'
        ]
    )
}}

select * from {{ ref('dim_hcp') }}

{% endsnapshot %}
