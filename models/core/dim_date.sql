{{
    config(
        materialized = 'table',
        schema = 'CORE',
        tags = ['core', 'dimension', 'date']
    )
}}

-- DIM_DATE: Calendar + pharma fiscal calendar dimension
-- Grain: One row per calendar date (2020-01-01 to ~2029-12-31)
-- Key: date_key (INTEGER YYYYMMDD for fast partition pruning)

with date_spine as (
    select dateadd(day, seq4(), '2020-01-01'::date) as calendar_date
    from table(generator(rowcount => 3653))
)

select
    to_number(to_char(calendar_date, 'YYYYMMDD'))           as date_key,
    calendar_date,

    dayofweek(calendar_date)                                 as day_of_week_num,
    dayname(calendar_date)                                   as day_of_week_name,
    dayofmonth(calendar_date)                                as day_of_month,
    dayofyear(calendar_date)                                 as day_of_year,
    case when dayofweek(calendar_date) in (0, 6) then true else false end as is_weekend,

    weekofyear(calendar_date)                                as week_of_year,
    date_trunc('week', calendar_date)                        as week_start_date,
    dateadd(day, 6, date_trunc('week', calendar_date))       as week_end_date,

    month(calendar_date)                                     as month_num,
    monthname(calendar_date)                                 as month_name,
    to_char(calendar_date, 'YYYY-MM')                        as year_month,
    date_trunc('month', calendar_date)                       as month_start_date,
    last_day(calendar_date, 'month')                         as month_end_date,
    case when calendar_date = last_day(calendar_date, 'month') then true else false end as is_month_end,

    quarter(calendar_date)                                   as quarter_num,
    'Q' || quarter(calendar_date)                            as quarter_name,
    year(calendar_date) || '-Q' || quarter(calendar_date)    as year_quarter,
    date_trunc('quarter', calendar_date)                     as quarter_start_date,
    last_day(calendar_date, 'quarter')                       as quarter_end_date,

    year(calendar_date)                                      as calendar_year,
    date_trunc('year', calendar_date)                        as year_start_date,
    last_day(calendar_date, 'year')                          as year_end_date,

    -- Pharma fiscal calendar (Oct 1 = FY start)
    case when month(calendar_date) >= 10
         then year(calendar_date) + 1
         else year(calendar_date)
    end                                                      as fiscal_year,
    case
        when month(calendar_date) in (10,11,12) then 1
        when month(calendar_date) in (1,2,3)    then 2
        when month(calendar_date) in (4,5,6)    then 3
        else 4
    end                                                      as fiscal_quarter,
    mod(month(calendar_date) + 2, 12) + 1                   as fiscal_month,

    case when calendar_date = current_date() then true else false end       as is_today,
    case when date_trunc('month', calendar_date) = date_trunc('month', current_date()) then true else false end as is_current_month,
    case when date_trunc('quarter', calendar_date) = date_trunc('quarter', current_date()) then true else false end as is_current_quarter,
    datediff(day, calendar_date, current_date())             as days_ago

from date_spine
