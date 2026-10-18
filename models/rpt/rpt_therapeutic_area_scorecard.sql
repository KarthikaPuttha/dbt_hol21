{{
    config(
        materialized = 'table',
        schema = 'RPT',
        tags = ['rpt', 'pharma', 'seeds_demo']
    )
}}

with sales_by_area as (
    -- Aggregate sales by therapeutic area and rep level
    select
        p.therapeutic_area,
        rep.rep_level,
        count(distinct s.txn_id)                as total_transactions,
        count(distinct s.rep_id)                as active_reps,
        count(distinct s.hcp_id)                as unique_hcps_reached,
        sum(s.quantity_sold)                    as total_units_sold,
        sum(s.net_amount)                       as total_net_revenue,
        sum(s.gross_amount)                     as total_gross_revenue,
        avg(s.net_amount)                       as avg_deal_size,
        avg(s.discount_pct)                     as avg_discount_pct
    from {{ ref('fct_sales') }} s
    inner join {{ ref('dim_product') }} p on s.product_id = p.product_id
    inner join {{ ref('dim_sales_rep') }} rep on s.rep_id = rep.rep_id
    group by 1, 2
),

-- =========================================================
-- JOIN #1: Seed as ENRICHMENT data
-- therapeutic_area_benchmarks adds industry context
-- that does NOT exist in our source systems
-- =========================================================
with_benchmarks as (
    select
        sa.*,
        bench.market_size_billions,
        bench.yoy_growth_pct                    as industry_growth_pct,
        bench.avg_rx_per_hcp                    as industry_avg_rx_per_hcp,
        bench.avg_deal_size                     as industry_avg_deal_size,
        bench.competitive_intensity,
        bench.notes                             as market_notes
    from sales_by_area sa
    left join {{ ref('therapeutic_area_benchmarks') }} bench
        on sa.therapeutic_area = bench.therapeutic_area
),

-- =========================================================
-- JOIN #2: Seed as REFERENCE data
-- rep_level_hierarchy adds HR metadata
-- (bonus rates, management flags, seniority)
-- =========================================================
with_rep_metadata as (
    select
        wb.*,
        rlh.seniority_rank,
        rlh.base_bonus_pct,
        rlh.can_manage_team,
        rlh.max_territories,
        rlh.title_abbreviation
    from with_benchmarks wb
    left join {{ ref('rep_level_hierarchy') }} rlh
        on wb.rep_level = rlh.rep_level
),

-- =========================================================
-- STEP 3: Compute attainment % so we can join to seed bands
-- =========================================================
with_attainment as (
    select
        wrm.*,

        -- Compare our avg deal size vs industry benchmark
        case
            when wrm.industry_avg_deal_size > 0
            then round(wrm.avg_deal_size / wrm.industry_avg_deal_size * 100, 2)
            else null
        end as deal_size_attainment_pct

    from with_rep_metadata wrm
)

-- =========================================================
-- JOIN #3: Seed as CONFIG-DRIVEN LOGIC
-- attainment_band_config replaces hardcoded CASE WHEN
-- Change the CSV → change the bands. No SQL edits needed.
-- =========================================================
select
    -- Grain keys
    wa.therapeutic_area,
    wa.rep_level,

    -- Sales measures
    wa.total_transactions,
    wa.active_reps,
    wa.unique_hcps_reached,
    wa.total_units_sold,
    wa.total_net_revenue,
    wa.total_gross_revenue,
    wa.avg_deal_size,
    wa.avg_discount_pct,

    -- From seed: therapeutic_area_benchmarks (ENRICHMENT)
    wa.market_size_billions,
    wa.industry_growth_pct,
    wa.industry_avg_deal_size,
    wa.competitive_intensity,
    wa.market_notes,

    -- From seed: rep_level_hierarchy (REFERENCE DATA)
    wa.seniority_rank,
    wa.base_bonus_pct,
    wa.can_manage_team,
    wa.title_abbreviation,

    -- Computed: how we compare to industry
    wa.deal_size_attainment_pct,

    -- From seed: attainment_band_config (CONFIG-DRIVEN LOGIC)
    -- This join replaces what would normally be a big CASE WHEN block
    band.band_name                              as performance_band,
    band.band_color                             as performance_color,
    band.bonus_multiplier,
    band.sort_order                             as band_sort_order,

    -- Calculated bonus: base_bonus_pct × bonus_multiplier
    round(wa.base_bonus_pct * coalesce(band.bonus_multiplier, 0), 2)
                                                as effective_bonus_pct,

    current_timestamp()                         as dw_loaded_at

from with_attainment wa
left join {{ ref('attainment_band_config') }} band
    on wa.deal_size_attainment_pct >= band.min_pct
    and wa.deal_size_attainment_pct <= band.max_pct
order by wa.therapeutic_area, wa.seniority_rank
