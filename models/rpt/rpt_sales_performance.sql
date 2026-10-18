{{
    config(
        materialized = 'table',
        schema = 'RPT',
        tags = ['rpt', 'sales', 'quota']
    )
}}

-- RPT_SALES_PERFORMANCE: Sales vs quota attainment by rep, product, territory, month
-- Grain: One row per rep + product + territory + month

with monthly_sales as (
    select
        s.rep_id,
        s.product_id,
        s.territory_id,
        d.year_month,
        d.calendar_year,
        d.quarter_name,
        d.fiscal_year,
        d.fiscal_quarter,
        d.month_name,
        count(*)                        as txn_count,
        sum(s.quantity_sold)            as total_units_sold,
        sum(s.gross_amount)             as total_gross_revenue,
        sum(s.net_amount)               as total_net_revenue,
        sum(s.discount_amount)          as total_discount,
        avg(s.discount_pct)             as avg_discount_pct,
        avg(s.unit_price)               as avg_unit_price
    from {{ ref('fct_sales') }} s
    inner join {{ ref('dim_date') }} d on s.date_key = d.date_key
    group by 1, 2, 3, 4, 5, 6, 7, 8, 9
),

targets as (
    select
        tgt.rep_id,
        tgt.product_id,
        tgt.territory_id,
        d.year_month,
        sum(tgt.target_amount)          as target_amount,
        sum(tgt.target_units)           as target_units
    from {{ ref('fct_sales_target') }} tgt
    inner join {{ ref('dim_date') }} d on tgt.date_key = d.date_key
    group by 1, 2, 3, 4
)

select
    {{ dbt_utils.generate_surrogate_key(['ms.rep_id', 'ms.product_id', 'ms.territory_id', 'ms.year_month']) }} as performance_sk,

    ms.year_month,
    ms.calendar_year,
    ms.quarter_name,
    ms.fiscal_year,
    ms.fiscal_quarter,
    ms.month_name,

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
    p.price_tier,

    -- Territory / Region
    t.territory_id,
    t.territory_name,
    t.state_name,
    r.region_id,
    r.region_name,
    r.zone,

    -- Sales measures
    ms.txn_count,
    ms.total_units_sold,
    ms.total_gross_revenue,
    ms.total_net_revenue,
    ms.total_discount,
    ms.avg_discount_pct,
    ms.avg_unit_price,

    -- Target measures
    coalesce(tgt.target_amount, 0)      as target_amount,
    coalesce(tgt.target_units, 0)       as target_units,

    -- Quota attainment KPIs
    case
        when coalesce(tgt.target_amount, 0) > 0
        then round(ms.total_net_revenue / tgt.target_amount * 100, 2)
        else null
    end                                 as revenue_attainment_pct,

    case
        when coalesce(tgt.target_units, 0) > 0
        then round(ms.total_units_sold / tgt.target_units * 100, 2)
        else null
    end                                 as units_attainment_pct,

    ms.total_net_revenue - coalesce(tgt.target_amount, 0) as revenue_vs_target_gap,

    case
        when coalesce(tgt.target_amount, 0) = 0 then 'No Target'
        when ms.total_net_revenue / tgt.target_amount >= 1.2 then 'Exceeds (120%+)'
        when ms.total_net_revenue / tgt.target_amount >= 1.0 then 'On Target (100-120%)'
        when ms.total_net_revenue / tgt.target_amount >= 0.8 then 'Below (80-100%)'
        else 'At Risk (<80%)'
    end                                 as attainment_band,

    current_timestamp()                 as dw_loaded_at

from monthly_sales ms
inner join {{ ref('dim_sales_rep') }}  rep on ms.rep_id = rep.rep_id
inner join {{ ref('dim_product') }}    p   on ms.product_id = p.product_id
inner join {{ ref('dim_territory') }}  t   on ms.territory_id = t.territory_id
inner join {{ ref('dim_region') }}     r   on t.region_id = r.region_id
left join  targets                     tgt on ms.rep_id = tgt.rep_id
                                           and ms.product_id = tgt.product_id
                                           and ms.territory_id = tgt.territory_id
                                           and ms.year_month = tgt.year_month
