-- Ad-hoc: Top reps by quota attainment for the current fiscal year
-- This query uses ref() but does NOT materialize — it compiles via `dbt compile`
-- and the rendered SQL can be run directly in a worksheet.

with rep_performance as (
    select
        rep_name,
        rep_level,
        region_name,
        zone,
        fiscal_year,
        sum(total_net_revenue)          as total_revenue,
        sum(target_amount)              as total_target,
        case
            when sum(target_amount) > 0
            then round(sum(total_net_revenue) / sum(target_amount) * 100, 1)
        end                             as attainment_pct,
        count(distinct year_month)      as months_active
    from {{ ref('rpt_sales_performance') }}
    where fiscal_year = (select max(fiscal_year) from {{ ref('rpt_sales_performance') }})
    group by 1, 2, 3, 4, 5
)

select
    rep_name,
    rep_level,
    region_name,
    zone,
    fiscal_year,
    total_revenue,
    total_target,
    attainment_pct,
    months_active,
    rank() over (order by attainment_pct desc nulls last) as attainment_rank
from rep_performance
where total_target > 0
order by attainment_pct desc
limit 25
