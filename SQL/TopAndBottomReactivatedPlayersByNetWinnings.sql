-- Top/Bottom Reactivated Players (Rachel lead): 
-- Rolling last 7, 30 (TBD max(gamingdate) logic), 
-- player info, and for each time period, net theo, net actual, freeplay, visit count
---- Inclusion criterial: requires the gap between most recent visit and prior visit to be 6+ months (180 days or more) 

-- calculate the churned date
with playerlags as
-- if it has the gap between the two most recent visits is 6+ months, then the player lapsed 7 months after their second most recent play
  (select 
        CasinoID
        , PlayerID
        , SetUpMonth
        , MostRecentPlayDate
        , MostRecentPlayMonth
        , SecondMostRecentPlayMonth
        , case when dateadd(month, 7, SecondMostRecentPlayMonth) < MostRecentPlayMonth then dateadd(month, 7, SecondMostRecentPlayMonth) 
            else null end as LapsedChurnDate

-- get the second most recent play date for all players
  from (select 
            CasinoID
            , PlayerID
            , SetUpMonth
            , MostRecentPlayDate
            , GamingMonth as MostRecentPlayMonth
            , case when LAG(GamingMonth,1) over (partition by PlayerID order by GamingMonth asc) is null and SetupMonth < '2022-01-01' then '2021-12-01' 
                else LAG(GamingMonth,1) over (partition by PlayerID order by GamingMonth asc) end SecondMostRecentPlayMonth

-- get the most recent play date for all players that have gaming activity
        from (select distinct 
                          pd.CasinoID
                          , pd.PlayerId
                          , date_trunc('month', dp.SetupDate) as SetUpMonth
                          , date_trunc('month', max(pd.GamingDate)) as GamingMonth -- most recent date played only 
                          , max(pd.GamingDate) as MostRecentPlayDate
              from prod_core.qcids.fact_playerday as pd
              left join prod_core.qcids.dim_player_scd as dp
                on pd.PlayerID = dp.PlayerID
              where pd.GamingDate < date_trunc('month', current_date())
                and pd.TotalVisit = 1
                group by 1,2,3) as act)
)

-- get most recent completed month's reactivated players
, reactivatedplayers as (
    select distinct
                CasinoID
                , PlayerID 
                , MostRecentPlayDate
                , MostRecentPlayMonth
                , SecondMostRecentPlayMonth
                , LapsedChurnDate
    from playerlags
    where MostRecentPlayDate >= dateadd(month, -1, current_date())  -- only consider data from last month
      and MostRecentPlayDate < date_trunc('month', current_date())
      and LapsedChurnDate is not null -- reactivated players only
)

-- calculate the top/bottom reactivated players by net win in the last 7 days
, last7days as (
    select distinct 
                pd.CasinoID
                , r.PlayerID
                , 'Last 7 Days' as TimePeriod
                , sum(pd.TotalVisit) as NumVisits
                , sum(pd.SlotActualWinNetFreeplayInt100 + pd.TableActualWinNetPromoCreditInt100)*.01 as NetWin
                , sum(pd.SlotFreeplayInt100 + pd.TablePromoCreditInt100)*.01 as NetTheo
                , sum(pd.SlotTheoWinNetFreeplayInt100 + pd.TableTheoWinNetPromoCreditInt100)*.01 as NetFreeplay
    from reactivatedplayers as r -- only consider reactivated players
    left join prod_core.qcids.fact_playerday as pd
      on r.PlayerID = pd.PlayerID
    where pd.TotalVisit = 1
        and pd.GamingDate >= dateadd(day, -7, current_date())
    group by 1, 2
    order by NetWin desc
)

-- calculate the top/bottom reactivated players by net win in the last 30 days
, last30days as (
    select distinct 
                pd.CasinoID
                , r.PlayerID
                , 'Last 30 Days' as TimePeriod
                , sum(pd.TotalVisit) as NumVisits
                , sum(pd.SlotActualWinNetFreeplayInt100 + pd.TableActualWinNetPromoCreditInt100)*.01 as NetWin
                , sum(pd.SlotFreeplayInt100 + pd.TablePromoCreditInt100)*.01 as NetTheo
                , sum(pd.SlotTheoWinNetFreeplayInt100 + pd.TableTheoWinNetPromoCreditInt100)*.01 as NetFreeplay
    from reactivatedplayers as r -- only consider reactivated players
    left join prod_core.qcids.fact_playerday as pd
      on r.PlayerID = pd.PlayerID
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