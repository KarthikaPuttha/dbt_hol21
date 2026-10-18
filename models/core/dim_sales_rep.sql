{{
    config(
        materialized = 'table',
        schema = 'CORE',
        tags = ['core', 'dimension', 'sales_force']
    )
}}

-- DIM_SALES_REP: Conformed rep dimension with tenure band, hierarchy, and territory
-- Grain: One row per sales rep

select
    {{ dbt_utils.generate_surrogate_key(['s.rep_id']) }} as rep_sk,
    s.rep_id,
    s.rep_name,
    s.email,
    s.phone,
    s.hire_date,
    s.tenure_months,
    s.rep_level,
    s.rep_status,
    s.is_active,

    -- Manager hierarchy (self-join one level up)
    s.manager_id,
    mgr.rep_name                             as manager_name,
    mgr.rep_level                            as manager_level,
    case when s.manager_id is null then true else false end as is_manager,

    -- Denormalized territory + region
    t.territory_id,
    t.territory_name,
    t.state_name,
    t.city_name,
    r.region_id,
    r.region_name,
    r.zone,

    case
        when s.tenure_months < 6   then '0-6 Months (New Hire)'
        when s.tenure_months < 12  then '6-12 Months (Ramping)'
        when s.tenure_months < 24  then '1-2 Years (Developing)'
        when s.tenure_months < 48  then '2-4 Years (Experienced)'
        else '4+ Years (Veteran)'
    end                                      as tenure_band,

    case s.rep_level
        when 'Regional Manager' then 4
        when 'Senior Sales Rep' then 3
        when 'Sales Rep II'     then 2
        when 'Sales Rep I'      then 1
        else 0
    end                                      as seniority_rank,

    s.record_source,
    s.loaded_at                              as effective_from,
    null::timestamp_ntz                      as effective_to,
    true                                     as is_current,
    current_timestamp()                      as dw_loaded_at

from {{ ref('stg_sales_rep') }} s
left join {{ ref('stg_sales_rep') }} mgr on s.manager_id = mgr.rep_id
left join {{ ref('stg_territory') }} t   on s.territory_id = t.territory_id
left join {{ ref('stg_region') }} r      on t.region_id = r.region_id
