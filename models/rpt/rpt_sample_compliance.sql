{{
    config(
        materialized = 'table',
        schema = 'RPT',
        tags = ['rpt', 'samples', 'compliance']
    )
}}

-- RPT_SAMPLE_COMPLIANCE: PDMA compliance report for sample utilization and waste
-- Grain: One row per rep + product + month

with monthly_samples as (
    select
        si.rep_id,
        si.product_id,
        d.year_month,
        d.calendar_year,
        d.fiscal_year,
        d.fiscal_quarter,
        count(*)                                as allocation_count,
        sum(si.allocated_qty)                   as total_allocated,
        sum(si.distributed_qty)                 as total_distributed,
        sum(si.remaining_qty)                   as total_remaining,
        sum(si.expired_waste_qty)               as total_expired_waste,
        avg(si.utilization_pct)                 as avg_utilization_pct,
        avg(si.shelf_life_days)                 as avg_shelf_life_days,
        sum(case when si.is_expired then 1 else 0 end) as expired_lot_count,
        sum(case when si.utilization_band = 'High' then 1 else 0 end)   as high_util_count,
        sum(case when si.utilization_band = 'Medium' then 1 else 0 end) as medium_util_count,
        sum(case when si.utilization_band = 'Low' then 1 else 0 end)    as low_util_count
    from {{ ref('fct_sample_inventory') }} si
    inner join {{ ref('dim_date') }} d on si.date_key = d.date_key
    group by 1, 2, 3, 4, 5, 6
)

select
    {{ dbt_utils.generate_surrogate_key(['ms.rep_id', 'ms.product_id', 'ms.year_month']) }} as compliance_sk,

    ms.year_month,
    ms.calendar_year,
    ms.fiscal_year,
    ms.fiscal_quarter,

    -- Rep attributes
    rep.rep_id,
    rep.rep_name,
    rep.rep_level,
    rep.tenure_band,
    rep.manager_name,
    rep.is_active                       as rep_is_active,

    -- Product attributes
    p.product_id,
    p.brand_name,
    p.therapeutic_area,
    p.product_lifecycle_stage,

    -- Territory / Region
    rep.territory_id,
    rep.territory_name,
    rep.state_name,
    rep.region_id,
    rep.region_name,
    rep.zone,

    -- Sample inventory measures
    ms.allocation_count,
    ms.total_allocated,
    ms.total_distributed,
    ms.total_remaining,
    ms.total_expired_waste,
    ms.avg_utilization_pct,
    ms.avg_shelf_life_days,
    ms.expired_lot_count,
    ms.high_util_count,
    ms.medium_util_count,
    ms.low_util_count,

    -- Compliance KPIs
    case
        when ms.total_allocated > 0
        then round(ms.total_distributed / ms.total_allocated * 100, 2)
        else 0
    end                                 as utilization_rate,

    case
        when ms.total_allocated > 0
        then round(ms.total_expired_waste / ms.total_allocated * 100, 2)
        else 0
    end                                 as waste_rate,

    case
        when ms.total_allocated > 0
        then round(ms.total_remaining / ms.total_allocated * 100, 2)
        else 0
    end                                 as inventory_holding_rate,

    -- PDMA Compliance status
    case
        when ms.total_allocated > 0 and ms.total_expired_waste / ms.total_allocated <= 0.05
             and ms.total_distributed / ms.total_allocated >= 0.70
            then 'Compliant'
        when ms.total_allocated > 0 and ms.total_expired_waste / ms.total_allocated <= 0.15
            then 'Warning'
        else 'Non-Compliant'
    end                                 as compliance_status,

    -- Risk flags
    case when ms.expired_lot_count > 0 then true else false end as has_expired_lots,
    case when ms.total_allocated > 0 and ms.total_expired_waste / ms.total_allocated > 0.10
         then true else false end       as high_waste_flag,
    case when ms.total_allocated > 0 and ms.total_distributed / ms.total_allocated < 0.50
         then true else false end       as low_utilization_flag,

    current_timestamp()                 as dw_loaded_at

from monthly_samples ms
inner join {{ ref('dim_sales_rep') }}  rep on ms.rep_id = rep.rep_id
inner join {{ ref('dim_product') }}    p   on ms.product_id = p.product_id
