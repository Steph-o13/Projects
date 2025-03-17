%sql
-- Compare the current YTD with previous year's YTD, joined on the fiscal calendar (fiscal week + fiscal day of week) (ROLLING)

-- dayofweek():
-- - Sunday = 1 
-- - Monday = 2 
-- - ...
-- - Saturday = 7


with YTD_fiscal_calendar_mapping as (
    select 
        row_number() over (order by post.GamingDate) as DayNum  -- mapping ID to connect the current date with the same fiscal day of previous year
        , post.GamingDate as cy_GamingDate
        , prev.GamingDate as py_GamingDate 

        , date_part('year', post.GamingDate) as cy_Year
        , date_part('year', prev.GamingDate) as py_Year

        , date_part('quarter', post.GamingDate) as cy_Quarter
        , date_part('quarter', prev.GamingDate) as py_Quarter

        , date_part('month', post.GamingDate) as cy_Month
        , date_part('month', prev.GamingDate) as py_Month

        , dayofweek(post.GamingDate) as cy_DayOfWeek
        , dayofweek(post.GamingDate) as py_DayOfWeek

    from polaris_scratchpad.gaming_marketing.x_ref_fiscal_calendar post
    left join polaris_scratchpad.gaming_marketing.x_ref_fiscal_calendar prev
        on post.FiscalYear = prev.FiscalYear+1                                          -- current year = previous year + 1
        and post.FiscalWeek = prev.FiscalWeek                                           -- current fiscal week = previous year's fiscal week
        and dayofweek(post.GamingDate) = dayofweek(prev.GamingDate)                     -- current fiscal day of week = previous year's fiscal week
    where date_part('year', post.GamingDate) = date_part('year', current_date())        -- where post.GamingDate is in the current year
)

-- calculate the daily total coinin, aggregated by game type, for the current year
, cy_daily_data as (
  select distinct
      p.CasinoID
      , m.DayNum
      , m.cy_Year
      , m.cy_Quarter 
      , m.cy_Month
      , cast(p.GamingDate as date)

      -- coin in / table drop
      , aggie.GameType 
      , aggie.CoinIn 

  from YTD_fiscal_calendar_mapping m 
  left join prod_core.qcids.fact_playerday p
      on m.CY_GamingDate = cast(p.GamingDate as date) -- only include dates in the current year
  left join prod_core.qcids.dim_player_scd d
      on d.PlayerID = p.PlayerID
  left join (
            select                                    -- slot-only
                CasinoID 
                , cast(GamingDate as date) 
                , 'slot' as GameType
                , sum(SlotCoinInInt100::int)*.01 as CoinIn
            from prod_core.qcids.fact_playerday
            where SlotVisit = 1
            group by CasinoID, GamingDate

            union all 

            select                                    -- table only
                CasinoID 
                , cast(GamingDate as date) 
                , 'table' as GameType
                , sum(TableBetAmountInt100)*.01 as CoinIn
            from prod_core.qcids.fact_playerday
            where TableVisit = 1
            group by CasinoID, GamingDate

            ) aggie 
      on p.CasinoID = aggie.CasinoID and cast(p.GamingDate as date) = cast(aggie.GamingDate as date)
 
  where p.TotalVisit = 1             -- where player has played  
      and d.IsCurrent = 1            -- with most current banned status
      and d.IsBanned = 0             -- not banned
)

-- calculate the daily total coinin, aggregated by game type, for the previous year
, py_daily_data as (
  select distinct
      p.CasinoID
      , m.DayNum
      , m.cy_Year
      , m.cy_Quarter 
      , m.cy_Month
      , cast(p.GamingDate as date)

      -- coin in / table drop
      , aggie.GameType 
      , aggie.CoinIn 

  from YTD_fiscal_calendar_mapping m 
  left join prod_core.qcids.fact_playerday p
      on m.PY_GamingDate = cast(p.GamingDate as date)     -- only include dates corresponding to the current quarter in the previous year
  left join prod_core.qcids.dim_player_scd d
      on d.PlayerID = p.PlayerID
  left join ( 
            select                                        -- slot only
                CasinoID 
                , cast(GamingDate as date) 
                , 'slot' as GameType
                , sum(SlotCoinInInt100::int)*.01 as CoinIn
            from prod_core.qcids.fact_playerday
            where SlotVisit = 1
            group by CasinoID, GamingDate

            union all 

            select                                        -- table only
                CasinoID 
                , cast(GamingDate as date) 
                , 'table' as GameType
                , sum(TableBetAmountInt100)*.01 as CoinIn
            from prod_core.qcids.fact_playerday
            where TableVisit = 1
            group by CasinoID, GamingDate

            ) aggie 
      on p.CasinoID = aggie.CasinoID and cast(p.GamingDate as date) = cast(aggie.GamingDate as date)
 
  where p.TotalVisit = 1             -- where player has played  
      and d.IsCurrent = 1            -- with most current banned status
      and d.IsBanned = 0             -- not banned
)

-- calculate the cumulative YTD metrics for both current and previous years
, cumulative as (
    select 
        c.CasinoID
        , c.GameType
        , c.GamingDate as cy_GamingDate
        , p.GamingDate as py_GamingDate
        
        , c.cy_Year
        , c.cy_Quarter 
        , c.cy_Month


        -- daily metrics 
        , c.CoinIn as cy_CoinIn
        , p.CoinIn as py_CoinIn

        -- cumulative YTD metrics
        , sum(c.CoinIn) over (partition by c.CasinoID, c.GameType, c.cy_Year order by c.GamingDate) as cy_cmlv_CoinIn_YTD 
        , sum(p.CoinIn) over (partition by c.CasinoID, c.GameType, c.cy_Year order by p.GamingDate) as py_cmlv_CoinIn_YTD

        -- cumulative QTD metrics
        , sum(c.CoinIn) over (partition by c.CasinoID, c.GameType, c.cy_Quarter order by c.GamingDate) as cy_cmlv_CoinIn_QTD
        , sum(p.CoinIn) over (partition by c.CasinoID, c.GameType, c.cy_Quarter order by p.GamingDate) as py_cmlv_CoinIn_QTD

        -- cumulative MTD metrics
        , sum(c.CoinIn) over (partition by c.CasinoID, c.GameType, c.cy_Month order by c.GamingDate) as cy_cmlv_CoinIn_MTD
        , sum(p.CoinIn) over (partition by c.CasinoID, c.GameType, c.cy_Month order by p.GamingDate) as py_cmlv_CoinIn_MTD

    from cy_daily_data c 
    join py_daily_data p 
        on c.DayNum = p.DayNum and c.CasinoID = p.CasinoID and c.GameType = p.GameType
)

select 
    CasinoID 
    , GameType 
    , cy_GamingDate
    , py_GamingDate 

    
    , cy_Quarter 
    , cy_Month

    , cy_CoinIn 
    , py_CoinIn 

    , round(cy_cmlv_CoinIn_YTD, 2) as cy_cmlv_CoinIn_YTD
    , round(py_cmlv_CoinIn_YTD, 2) as py_cmlv_CoinIn_YTD

    , round(cy_cmlv_CoinIn_QTD, 2) as cy_cmlv_CoinIn_QTD
    , round(py_cmlv_CoinIn_QTD, 2) as py_cmlv_CoinIn_QTD

    , round(cy_cmlv_CoinIn_MTD, 2) as cy_cmlv_CoinIn_MTD
    , round(py_cmlv_CoinIn_MTD, 2) as py_cmlv_CoinIn_MTD

from cumulative 
 
order by cy_GamingDate, casinoID, GameType 

