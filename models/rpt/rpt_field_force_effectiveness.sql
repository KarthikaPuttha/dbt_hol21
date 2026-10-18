{{
    config(
        materialized = 'table',
        schema = 'RPT',
        tags = ['rpt', 'field_force', 'effectiveness']
    )
}}

-- RPT_FIELD_FORCE_EFFECTIVENESS: Rep call productivity and conversion metrics
-- Grain: One row per rep + territory + month

with monthly_calls as (
    select
        ca.rep_id,
        ca.territory_id,
        d.year_month,
        d.calendar_year,
        d.fiscal_year,
        d.fiscal_quarter,
        sum(ca.total_call_count)        as total_calls,
        sum(ca.completed_call_count)    as completed_calls,
        sum(ca.missed_call_count)       as missed_calls,
        sum(ca.calls_with_samples)      as calls_with_samples,
        sum(ca.samples_dropped_count)   as total_samples_dropped,
        avg(ca.call_duration_minutes)   as avg_call_duration_minutes,
        count(distinct ca.hcp_id)       as unique_hcps_visited
    from {{ ref('fct_call_activity') }} ca
    inner join {{ ref('dim_date') }} d on ca.date_key = d.date_key
    group by 1, 2, 3, 4, 5, 6
),

monthly_sales as (
    select
        s.rep_id,
        s.territory_id,
        d.year_month,
        count(*)                        as txn_count,
        sum(s.quantity_sold)            as total_units_sold,
        sum(s.net_amount)               as total_net_revenue,
        count(distinct s.hcp_id)        as unique_hcps_sold
    from {{ ref('fct_sales') }} s
    inner join {{ ref('dim_date') }} d on s.date_key = d.date_key
    group by 1, 2, 3
)

select
    {{ dbt_utils.generate_surrogate_key(['mc.rep_id', 'mc.territory_id', 'mc.year_month']) }} as effectiveness_sk,

    mc.year_month,
    mc.calendar_year,
    mc.fiscal_year,
    mc.fiscal_quarter,

    -- Rep attributes
    rep.rep_id,
    rep.rep_name,
    rep.rep_level,
    rep.tenure_band,
    rep.seniority_rank,
    rep.manager_name,
    rep.is_active                       as rep_is_active,

    -- Territory / Region
    t.territory_id,
    t.territory_name,
    t.state_name,
    r.region_id,
    r.region_name,
    r.zone,

    -- Call metrics
    mc.total_calls,
    mc.completed_calls,
    mc.missed_calls,
    mc.calls_with_samples,
    mc.total_samples_dropped,
    mc.avg_call_duration_minutes,
    mc.unique_hcps_visited,

    -- Sales metrics
    coalesce(ms.txn_count, 0)           as txn_count,
    coalesce(ms.total_units_sold, 0)    as total_units_sold,
    coalesce(ms.total_net_revenue, 0)   as total_net_revenue,
    coalesce(ms.unique_hcps_sold, 0)    as unique_hcps_sold,

    -- Productivity KPIs
    case
        when mc.total_calls > 0
        then round(mc.completed_calls / mc.total_calls * 100, 2)
        else 0
    end                                 as call_completion_rate,

    case
        when mc.total_calls > 0
        then round(coalesce(ms.total_net_revenue, 0) / mc.total_calls, 2)
        else 0
    end                                 as revenue_per_call,

    case
        when mc.completed_calls > 0
        then round(coalesce(ms.total_net_revenue, 0) / mc.completed_calls, 2)
        else 0
    end                                 as revenue_per_completed_call,

    case
        when mc.unique_hcps_visited > 0
        then round(coalesce(ms.total_net_revenue, 0) / mc.unique_hcps_visited, 2)
        else 0
    end                                 as revenue_per_hcp,

    case
        when mc.unique_hcps_visited > 0
        then round(mc.completed_calls / mc.unique_hcps_visited, 2)
        else 0
    end                                 as avg_calls_per_hcp,

    -- Conversion: HCPs visited who generated sales
    case
        when mc.unique_hcps_visited > 0
        then round(coalesce(ms.unique_hcps_sold, 0) / mc.unique_hcps_visited * 100, 2)
        else 0
    end                                 as hcp_conversion_rate,

    -- Effectiveness rating
    case
        when mc.total_calls > 0 and mc.completed_calls / mc.total_calls >= 0.85
             and coalesce(ms.total_net_revenue, 0) / mc.completed_calls >= 500
            then 'Star Performer'
        when mc.total_calls > 0 and mc.completed_calls / mc.total_calls >= 0.70
             and coalesce(ms.total_net_revenue, 0) / mc.completed_calls >= 200
            then 'Effective'
        when mc.total_calls > 0 and mc.completed_calls / mc.total_calls >= 0.50
            then 'Developing'
        else 'Needs Improvement'
    end                                 as effectiveness_rating,

    current_timestamp()                 as dw_loaded_at

from monthly_calls mc
inner join {{ ref('dim_sales_rep') }}  rep on mc.rep_id = rep.rep_id
inner join {{ ref('dim_territory') }}  t   on mc.territory_id = t.territory_id
inner join {{ ref('dim_region') }}     r   on t.region_id = r.region_id
left join  monthly_sales               ms  on mc.rep_id = ms.rep_id
                                           and mc.territory_id = ms.territory_id
                                           and mc.year_month = ms.year_month
