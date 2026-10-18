{{
    config(
        materialized = 'table',
        schema = 'RPT',
        tags = ['rpt', 'product', 'portfolio']
    )
}}

-- RPT_PRODUCT_PORTFOLIO: Product-level revenue, Rx, and market metrics
-- Grain: One row per product + territory + month

with monthly_sales as (
    select
        s.product_id,
        s.territory_id,
        d.year_month,
        d.calendar_year,
        d.fiscal_year,
        d.fiscal_quarter,
        sum(s.quantity_sold)            as units_sold,
        sum(s.gross_amount)             as gross_revenue,
        sum(s.net_amount)               as net_revenue,
        sum(s.discount_amount)          as total_discount,
        avg(s.discount_pct)             as avg_discount_pct,
        count(distinct s.rep_id)        as reps_selling,
        count(distinct s.hcp_id)        as hcps_purchasing
    from {{ ref('fct_sales') }} s
    inner join {{ ref('dim_date') }} d on s.date_key = d.date_key
    group by 1, 2, 3, 4, 5, 6
),

monthly_rx as (
    select
        rx.product_id,
        rx.territory_id,
        d.year_month,
        sum(rx.total_rx_count)          as total_rx_count,
        sum(rx.is_new_rx)               as new_rx_count,
        sum(rx.is_refill_rx)            as refill_rx_count,
        sum(rx.is_switch_rx)            as switch_rx_count,
        sum(rx.total_rx_value)          as total_rx_value,
        count(distinct rx.hcp_id)       as hcps_prescribing
    from {{ ref('fct_prescriptions') }} rx
    inner join {{ ref('dim_date') }} d on rx.date_key = d.date_key
    group by 1, 2, 3
),

-- Total revenue per territory-month for market share calculation
territory_totals as (
    select
        territory_id,
        year_month,
        sum(net_revenue)                as territory_total_revenue,
        sum(units_sold)                 as territory_total_units
    from monthly_sales
    group by 1, 2
)

select
    {{ dbt_utils.generate_surrogate_key(['ms.product_id', 'ms.territory_id', 'ms.year_month']) }} as portfolio_sk,

    ms.year_month,
    ms.calendar_year,
    ms.fiscal_year,
    ms.fiscal_quarter,

    -- Product attributes
    p.product_id,
    p.product_name,
    p.brand_name,
    p.therapeutic_area,
    p.product_category,
    p.product_lifecycle_stage,
    p.price_tier,
    p.current_unit_price,
    p.months_since_launch,
    p.months_to_patent_expiry,
    p.is_patent_active,

    -- Territory / Region
    t.territory_id,
    t.territory_name,
    t.state_name,
    r.region_id,
    r.region_name,
    r.zone,

    -- Sales measures
    ms.units_sold,
    ms.gross_revenue,
    ms.net_revenue,
    ms.total_discount,
    ms.avg_discount_pct,
    ms.reps_selling,
    ms.hcps_purchasing,

    -- Prescription measures
    coalesce(mrx.total_rx_count, 0)     as total_rx_count,
    coalesce(mrx.new_rx_count, 0)       as new_rx_count,
    coalesce(mrx.refill_rx_count, 0)    as refill_rx_count,
    coalesce(mrx.switch_rx_count, 0)    as switch_rx_count,
    coalesce(mrx.total_rx_value, 0)     as total_rx_value,
    coalesce(mrx.hcps_prescribing, 0)   as hcps_prescribing,

    -- Portfolio KPIs
    case
        when coalesce(mrx.total_rx_count, 0) > 0
        then round(mrx.new_rx_count / mrx.total_rx_count * 100, 2)
        else 0
    end                                 as nrx_share_pct,

    case
        when ms.units_sold > 0
        then round(ms.net_revenue / ms.units_sold, 2)
        else 0
    end                                 as revenue_per_unit,

    -- Territory market share
    case
        when tt.territory_total_revenue > 0
        then round(ms.net_revenue / tt.territory_total_revenue * 100, 2)
        else 0
    end                                 as territory_revenue_share_pct,

    case
        when tt.territory_total_units > 0
        then round(ms.units_sold / tt.territory_total_units * 100, 2)
        else 0
    end                                 as territory_unit_share_pct,

    current_timestamp()                 as dw_loaded_at

from monthly_sales ms
inner join {{ ref('dim_product') }}    p   on ms.product_id = p.product_id
inner join {{ ref('dim_territory') }}  t   on ms.territory_id = t.territory_id
inner join {{ ref('dim_region') }}     r   on t.region_id = r.region_id
left join  monthly_rx                  mrx on ms.product_id = mrx.product_id
                                           and ms.territory_id = mrx.territory_id
                                           and ms.year_month = mrx.year_month
left join  territory_totals            tt  on ms.territory_id = tt.territory_id
                                           and ms.year_month = tt.year_month
