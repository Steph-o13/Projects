-- Top/Bottom Players (Rachel lead): 
-- Rolling last 7, 30 (TBD max(gamingdate) logic), 
-- player info, and for each time period, net theo, net actual, freeplay, visit count

-- calculate the top/bottom players by net win in the last 7 days
with last7days as (
    select distinct 
                  pd.CasinoID
                  , pd.PlayerID
                  , 'Last 7 Days' as TimePeriod
                  , sum(pd.TotalVisit) as NumVisits
                  , sum(pd.SlotActualWinNetFreeplayInt100 + pd.TableActualWinNetPromoCreditInt100)*.01 as NetWin
                  , sum(pd.SlotFreeplayInt100 + pd.TablePromoCreditInt100)*.01 as NetTheo
                  , sum(pd.SlotTheoWinNetFreeplayInt100 + pd.TableTheoWinNetPromoCreditInt100)*.01 as NetFreeplay
    from prod_core.qcids.fact_playerday as pd
    where pd.TotalVisit = 1
        and pd.GamingDate >= dateadd(day, -7, current_date())
    group by 1, 2
    order by NetWin desc
)

-- calculate the top/bottom players by net win in the last 30 days
, last30days as (
    select distinct 
                  pd.CasinoID
                  , pd.PlayerID
                  , 'Last 30 Days' as TimePeriod
                  , sum(pd.TotalVisit) as NumVisits
                  , sum(pd.SlotActualWinNetFreeplayInt100 + pd.TableActualWinNetPromoCreditInt100)*.01 as NetWin
                  , sum(pd.SlotFreeplayInt100 + pd.TablePromoCreditInt100)*.01 as NetTheo
                  , sum(pd.SlotTheoWinNetFreeplayInt100 + pd.TableTheoWinNetPromoCreditInt100)*.01 as NetFreeplay
    from prod_core.qcids.fact_playerday as pd
    where pd.TotalVisit = 1
        and pd.GamingDate >= dateadd(day, -30, current_date())
    group by 1, 2
    order by NetWin desc
)

-- get the top/bottom 50 players from the last 7 days and last 30 days
, topandbottom as (
                  select * from (select * from last7days order by NetWin desc limit 50) as top50_7
                  union all
                  select * from (select * from last7days order by NetWin asc limit 50) as bottom50_7
                  union all
                  select * from (select * from last30days order by NetWin desc limit 50) as top50_30
                  union all
                  select * from (select * from last30days order by NetWin asc limit 50) as bottom50_30
)

select * from topandbottom order by NetWin desc