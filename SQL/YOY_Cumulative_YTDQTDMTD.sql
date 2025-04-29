-- Compare the current YTD with previous year's YTD, joined on the fiscal calendar (fiscal week + fiscal day of week)

-- dayofweek():
-- - Sunday = 1 
-- - Monday = 2 
-- - ...
-- - Saturday = 7

-- get all dates from 2024 to now, to ensure days with zero play aren't excluded from gamingdate
WITH CTE_Dates AS ( -- FLG and HAM don't have table
                        -- limit to dates before current date so we don't end up with a bunch of zeroes for future dates in the final output
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

-- calculate the daily total coinin, aggregated on GameType, Casino, FiscalYear
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

  from CTE_Dates m 
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
)


, cumulative as (
    select 
        *
        -- cumulative YTD metrics
        , sum(CoinIn) over (partition by CasinoID, GameType, FiscalYear order by GamingDate) as cmlv_CoinIn_YTD 
        , sum(NetWin) over (partition by CasinoID, GameType, FiscalYear order by GamingDate) as cmlv_NetWin_YTD 

        -- cumulative QTD metrics
        , sum(CoinIn) over (partition by CasinoID, GameType, CalQuarter order by GamingDate) as cmlv_CoinIn_QTD
        , sum(NetWin) over (partition by CasinoID, GameType, CalQuarter order by GamingDate) as cmlv_NetWin_QTD

        -- cumulative MTD metrics
        , sum(CoinIn) over (partition by CasinoID, GameType, CalMonth order by GamingDate) as cmlv_CoinIn_MTD
        , sum(NetWin) over (partition by CasinoID, GameType, CalMonth order by GamingDate) as cmlv_NetWin_MTD

    from daily_data
)

select 
    cy.CasinoID 
    , cy.GameType 

    , cy.CalQuarter 
    , cy.CalMonth

    , cy.GamingDate  as cy_GamingDate
    , py.GamingDate as py_GamingDate

    -- CoinIn
        -- current year
    , cy.CoinIn as cy_CoinIn
    , round(cy.cmlv_CoinIn_YTD, 2) as cy_cmlv_CoinIn_YTD   
    , round(cy.cmlv_CoinIn_QTD, 2) as cy_cmlv_CoinIn_QTD 
    , round(cy.cmlv_CoinIn_MTD, 2) as cy_cmlv_CoinIn_MTD
        
        -- previous year
    , py.CoinIn as py_CoinIn
    , round(py.cmlv_CoinIn_YTD, 2) as py_cmlv_CoinIn_YTD
    , round(py.cmlv_CoinIn_QTD, 2) as py_cmlv_CoinIn_QTD
    , round(py.cmlv_CoinIn_MTD, 2) as py_cmlv_CoinIn_MTD

    -- NetWin
        -- current year
    , cy.NetWin as cy_NetWin
    , round(cy.cmlv_NetWin_YTD, 2) as cy_cmlv_NetWin_YTD
    , round(cy.cmlv_NetWin_QTD, 2) as cy_cmlv_NetWin_QTD
    , round(cy.cmlv_NetWin_MTD, 2) as cy_cmlv_NetWin_MTD

        -- previous year
    , py.NetWin as py_NetWin
    , round(py.cmlv_NetWin_YTD, 2) as py_cmlv_NetWin_YTD
    , round(py.cmlv_NetWin_QTD, 2) as py_cmlv_NetWin_QTD
    , round(py.cmlv_NetWin_MTD, 2) as py_cmlv_NetWin_MTD

from (select * from cumulative where FiscalYear = datepart('year', dateadd(DAY, -2, current_date()))) cy
left join (select * from cumulative where FiscalYear = datepart('year', dateadd(DAY, -367, current_date()))) py
    on cy.CasinoID = py.CasinoID 
    and cy.GameType = py.GameType 
    and cy.FiscalYear = (py.FiscalYear + 1) 
    and cy.FiscalWeek = py.FiscalWeek 
    and cy.DayOfWeek = py.DayOfWeek
order by cy_GamingDate, cy.casinoID, cy.GameType
