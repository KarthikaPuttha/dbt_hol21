{{
    config(
        materialized = 'table',
        schema = 'RPT',
        tags = ['rpt', 'hcp', 'prescriber']
    )
}}

-- RPT_PRESCRIBER_360: 360-degree HCP view combining Rx, calls, and samples
-- Grain: One row per HCP + product + month

with monthly_rx as (
    select
        rx.hcp_id,
        rx.product_id,
        rx.territory_id,
        d.year_month,
        d.calendar_year,
        d.fiscal_year,
        d.fiscal_quarter,
        sum(rx.total_rx_count)          as total_rx_count,
        sum(rx.is_new_rx)               as new_rx_count,
        sum(rx.is_refill_rx)            as refill_rx_count,
        sum(rx.is_switch_rx)            as switch_rx_count,
        sum(rx.rx_quantity)             as total_rx_quantity,
        sum(rx.total_rx_value)          as total_rx_value
    from {{ ref('fct_prescriptions') }} rx
    inner join {{ ref('dim_date') }} d on rx.date_key = d.date_key
    group by 1, 2, 3, 4, 5, 6, 7
),

monthly_calls as (
    select
        ca.hcp_id,
        ca.territory_id,
        d.year_month,
        sum(ca.total_call_count)        as total_calls,
        sum(ca.completed_call_count)    as completed_calls,
        sum(ca.missed_call_count)       as missed_calls,
        sum(ca.calls_with_samples)      as calls_with_samples,
        sum(ca.samples_dropped_count)   as total_samples_dropped,
        avg(ca.call_duration_minutes)   as avg_call_duration_minutes
    from {{ ref('fct_call_activity') }} ca
    inner join {{ ref('dim_date') }} d on ca.date_key = d.date_key
    group by 1, 2, 3
)

select
    {{ dbt_utils.generate_surrogate_key(['mrx.hcp_id', 'mrx.product_id', 'mrx.year_month']) }} as prescriber_360_sk,

    mrx.year_month,
    mrx.calendar_year,
    mrx.fiscal_year,
    mrx.fiscal_quarter,

    -- HCP attributes
    h.hcp_id,
    h.hcp_name,
    h.specialty,
    h.specialty_group,
    h.hospital_name,
    h.hcp_tier,
    h.hcp_decile,
    h.prescribing_potential_score,
    h.hcp_status,
    h.is_active                         as hcp_is_active,

    -- Product
    p.product_id,
    p.brand_name,
    p.therapeutic_area,
    p.product_lifecycle_stage,

    -- Territory / Region
    t.territory_id,
    t.territory_name,
    t.state_name,
    r.region_id,
    r.region_name,
    r.zone,

    -- Prescription measures
    mrx.total_rx_count,
    mrx.new_rx_count,
    mrx.refill_rx_count,
    mrx.switch_rx_count,
    mrx.total_rx_quantity,
    mrx.total_rx_value,
    case
        when mrx.total_rx_count > 0
        then round(mrx.new_rx_count / mrx.total_rx_count * 100, 2)
        else 0
    end                                 as nrx_share_pct,

    -- Call activity measures
    coalesce(mc.total_calls, 0)         as total_calls,
    coalesce(mc.completed_calls, 0)     as completed_calls,
    coalesce(mc.missed_calls, 0)        as missed_calls,
    coalesce(mc.calls_with_samples, 0)  as calls_with_samples,
    coalesce(mc.total_samples_dropped, 0) as total_samples_dropped,
    mc.avg_call_duration_minutes,

    -- Engagement KPIs
    case
        when coalesce(mc.total_calls, 0) > 0
        then round(mc.completed_calls / mc.total_calls * 100, 2)
        else null
    end                                 as call_completion_rate,

    case
        when coalesce(mc.completed_calls, 0) > 0
        then round(mrx.total_rx_count / mc.completed_calls, 2)
        else null
    end                                 as rx_per_call,

    case
        when coalesce(mc.total_calls, 0) >= 4 and mrx.total_rx_count >= 5 then 'High Engagement'
        when coalesce(mc.total_calls, 0) >= 2 and mrx.total_rx_count >= 2 then 'Medium Engagement'
        when coalesce(mc.total_calls, 0) >= 1 then 'Low Engagement'
        else 'No Engagement'
    end                                 as engagement_tier,

    current_timestamp()                 as dw_loaded_at

from monthly_rx mrx
inner join {{ ref('dim_hcp') }}        h   on mrx.hcp_id = h.hcp_id
inner join {{ ref('dim_product') }}    p   on mrx.product_id = p.product_id
inner join {{ ref('dim_territory') }}  t   on mrx.territory_id = t.territory_id
inner join {{ ref('dim_region') }}     r   on t.region_id = r.region_id
left join  monthly_calls               mc  on mrx.hcp_id = mc.hcp_id
                                           and mrx.territory_id = mc.territory_id
                                           and mrx.year_month = mc.year_month
