
-- YOY YTD MTD QTD
-- Compare the current YTD with previous year's YTD, joined on the fiscal calendar (fiscal week + fiscal day of week)

-- dayofweek():
-- - Sunday = 1 
-- - Monday = 2 
-- - ...
-- - Saturday = 7

-- get all dates from 2024 to now, to ensure days with zero play aren't excluded from gamingdate
WITH CTE_Dates AS ( -- FLG and HAM don't have table
        SELECT 'FLG' CasinoID, 'slot' GameType, DayOfWeek(GamingDate) DayOfWeek, * FROM polaris_scratchpad.gaming_marketing.x_ref_fiscal_calendar dt WHERE GamingDate >= '2024-01-01' and GamingDate <= current_date()
        UNION ALL
        SELECT 'GCC' CasinoID, 'slot' GameType, DayOfWeek(GamingDate) DayOfWeek, * FROM polaris_scratchpad.gaming_marketing.x_ref_fiscal_calendar dt WHERE GamingDate >= '2024-01-01' and GamingDate <= current_date()
        UNION ALL
        SELECT 'GCC' CasinoID, 'table' GameType, DayOfWeek(GamingDate) DayOfWeek, * FROM polaris_scratchpad.gaming_marketing.x_ref_fiscal_calendar dt WHERE GamingDate >= '2024-01-01' and GamingDate <= current_date()
        UNION ALL
        SELECT 'HAM' CasinoID, 'slot' GameType, DayOfWeek(GamingDate) DayOfWeek, * FROM polaris_scratchpad.gaming_marketing.x_ref_fiscal_calendar dt WHERE GamingDate >= '2024-01-01' and GamingDate <= current_date()
        UNION ALL
        SELECT 'MGC' CasinoID, 'slot' GameType, DayOfWeek(GamingDate) DayOfWeek, * FROM polaris_scratchpad.gaming_marketing.x_ref_fiscal_calendar dt WHERE GamingDate >= '2024-01-01' and GamingDate <= current_date()
        UNION ALL
        SELECT 'MGC' CasinoID, 'table' GameType, DayOfWeek(GamingDate) DayOfWeek, * FROM polaris_scratchpad.gaming_marketing.x_ref_fiscal_calendar dt WHERE GamingDate >= '2024-01-01' and GamingDate <= current_date()
        UNION ALL
        SELECT 'SOU' CasinoID, 'slot' GameType, DayOfWeek(GamingDate) DayOfWeek, * FROM polaris_scratchpad.gaming_marketing.x_ref_fiscal_calendar dt WHERE GamingDate >= '2024-01-01' and GamingDate <= current_date()
        UNION ALL
        SELECT 'SOU' CasinoID, 'table' GameType, DayOfWeek(GamingDate) DayOfWeek, * FROM polaris_scratchpad.gaming_marketing.x_ref_fiscal_calendar dt WHERE GamingDate >= '2024-01-01' and GamingDate <= current_date()
        UNION ALL
        SELECT 'WIC' CasinoID, 'slot' GameType, DayOfWeek(GamingDate) DayOfWeek, * FROM polaris_scratchpad.gaming_marketing.x_ref_fiscal_calendar dt WHERE GamingDate >= '2024-01-01' and GamingDate <= current_date()
        UNION ALL
        SELECT 'WIC' CasinoID, 'table' GameType, DayOfWeek(GamingDate) DayOfWeek, * FROM polaris_scratchpad.gaming_marketing.x_ref_fiscal_calendar dt WHERE GamingDate >= '2024-01-01' and GamingDate <= current_date()
)

-- remove any leap days
, leap_aggie (
    select
      case when day(GamingDate) = 29 and month(GamingDate) = 2 then 1 else 0 end as IsLeapDay
        , *
    from cte_dates
)

-- calculate the daily total coinin, aggregated on GameType, Year
, daily_data as (
  select distinct
      m.CasinoID
      , m.FiscalYear
      , date_part('quarter', m.GamingDate) as CalQuarter 
      , date_part('month', m.GamingDate) as CalMonth
      , m.FiscalWeek
      , m.DayOfWeek
      , m.GamingDate
      , row_number() over (partition by m.CasinoID, m.fiscalYear order by m.GamingDate) as DayNum 

      -- coin in / table drop
      , m.GameType 
      , coalesce(aggie.CoinIn,0) as CoinIn
      , coalesce(aggie.NetWin,0) as NetWin

  from leap_aggie m 
  left join ( 
            select                                        -- slot only
                CasinoID 
                , cast(GamingDate as date) 
                , 'slot' as GameType
                , sum(SlotCoinInInt100::int)*.01 as CoinIn
                , sum(SlotActualWinNetFreeplayInt100::int)*.01 as NetWin
            from prod_core.qcids.fact_playerday pd
            left join prod_core.qcids.dim_player_scd d
                    on d.PlayerID = pd.PlayerID and IsCurrent = 1
            where pd.SlotVisit = 1
                 and d.IsBanned = 0
            group by CasinoID, GamingDate

            union all 

            select                                        -- table only
                CasinoID 
                , cast(GamingDate as date) 
                , 'table' as GameType
                , sum(TableBetAmountInt100)*.01 as CoinIn
                , sum(TableActualWinNetPromoCreditInt100::int)*.01 as NetWin
            from prod_core.qcids.fact_playerday pd
            left join prod_core.qcids.dim_player_scd d
                    on d.PlayerID = pd.PlayerID and IsCurrent = 1
            where pd.TableVisit = 1
                and d.IsBanned = 0
            group by CasinoID, GamingDate

            ) aggie 
      on m.CasinoID = aggie.CasinoID 
        and m.GamingDate = cast(aggie.GamingDate as date) 
        and m.GameType = aggie.GameType
    where m.IsLeapDay <> 1 -- remove leap days
        and m.GamingDate <= dateadd(day, -2, current_date()) -- don't include the delayed data not yet in databricks
)

select 
    cy.CasinoID 
    , cy.GameType 

    , cy.GamingDate as cy_GamingDate
    , py.GamingDate as py_GamingDate

    -- CoinIn
    , cy.CoinIn as cy_CoinIn
    , round(sum(cy.CoinIn) over (partition by cy.CasinoID, cy.GameType, cy.FiscalYear order by cy.GamingDate), 2) as cy_cmlv_CoinIn_YTD   
    , round(sum(cy.CoinIn) over (partition by cy.CasinoID, cy.GameType, cy.FiscalYear, cy.CalQuarter order by cy.GamingDate), 2) as cy_cmlv_CoinIn_QTD 
    , round(sum(cy.CoinIn) over (partition by cy.CasinoID, cy.GameType, cy.FiscalYear, cy.CalMonth order by cy.GamingDate), 2) as cy_cmlv_CoinIn_MTD

    , py.CoinIn as py_CoinIn
    , round(sum(py.CoinIn) over (partition by py.CasinoID, py.GameType, py.FiscalYear order by py.GamingDate), 2) as py_cmlv_CoinIn_YTD   
    , round(sum(py.CoinIn) over (partition by py.CasinoID, py.GameType, py.FiscalYear, py.CalQuarter order by py.GamingDate), 2) as py_cmlv_CoinIn_QTD 
    , round(sum(py.CoinIn) over (partition by py.CasinoID, py.GameType, py.FiscalYear, py.CalMonth order by py.GamingDate), 2) as py_cmlv_CoinIn_MTD

    -- NetWin
    , cy.NetWin as cy_NetWin
    , round(sum(cy.NetWin) over (partition by cy.CasinoID, cy.GameType, cy.FiscalYear order by cy.GamingDate), 2) as cy_cmlv_NetWin_YTD
    , round(sum(cy.NetWin) over (partition by cy.CasinoID, cy.GameType, cy.FiscalYear, cy.CalQuarter order by cy.GamingDate), 2) as cy_cmlv_NetWin_QTD
    , round(sum(cy.NetWin) over (partition by cy.CasinoID, cy.GameType, cy.FiscalYear, cy.CalMonth order by cy.GamingDate), 2) as cy_cmlv_NetWin_MTD

    , py.NetWin as py_NetWin
    , round(sum(py.NetWin) over (partition by py.CasinoID, py.GameType, py.FiscalYear order by py.GamingDate), 2) as py_cmlv_NetWin_YTD
    , round(sum(py.NetWin) over (partition by py.CasinoID, py.GameType, py.FiscalYear, py.CalQuarter order by py.GamingDate), 2) as py_cmlv_NetWin_QTD
    , round(sum(py.NetWin) over (partition by py.CasinoID, py.GameType, py.FiscalYear, py.CalMonth order by py.GamingDate), 2) as py_cmlv_NetWin_MTD

from (select * from daily_data where FiscalYear = datepart('year', dateadd(DAY, -2, current_date()))) cy  -- where fiscal year = current year
left join (select * from daily_data where FiscalYear = datepart('year', dateadd(DAY, -367, current_date()))) py -- where fiscal year = previous year
    on cy.CasinoID = py.CasinoID 
    and cy.GameType = py.GameType 
    and cy.GamingDate = dateadd(year, 1, py.GamingDate)
order by cy.casinoID, cy.CasinoID, cy.GameType

