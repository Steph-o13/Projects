 
-- how many high value players (by ADT) are unhosted?
-- Criteria:
---- Filter: all and by property
---- Sort: descending based on ADT
---- Inclusion: any players at or above $400 ADT within the last six months, unhosted players only
---- Columns: Casino ID, Account ID, Signup Year, Host Name, Max Gaming Date, Days Since Last Visit, Prior 6 Month Net Theo, Prior 6 Month net Actual, Prior 6 Month Median Trip Theo, Prior 6 Month Visit Count
with playerinfo as (
-- get basic player info, including if they are hosted or not
    select 
        left(a.PlayerID, 3) as CasinoID
        , a.PlayerID
        , case when b.PlayerID is not null then 1 else 0 end as Hosted
        , cast(c.SetupDate as date) as SignupDate
        , concat(b.HostFirstName, " ", b.HostLastName) as HostName
    from polaris_scratchpad.gaming_marketing.playerchurn_overdue_v9 a
    left join (select e.*, d.PlayerID 
               from prod_core.qcids.dim_playerhost_SCD d
               left join prod_core.qcids.Dim_host_scd e 
                 on d.HostID = e.HostID
               where d.IsCurrent = 1 and e.IsCurrent = 1) b
        on a.PlayerID = b.PlayerID
    left join (select * 
               from prod_core.qcids.dim_player_SCD 
               where IsCurrent = 1) c 
        on a.PlayerID = c.PlayerID
)
, last6months as (
-- calculate unhosted players' activity from the last 6 months
    select 
        pi.CasinoID
        , pi.PlayerID
        , year(pi.SignupDate) as SignupYear
        , pi.HostName 
        , 'Last 6 Months' as TimePeriod
        , sum(pd.TotalVisit) as NumVisits
        , max(pd.GamingDate) as MaxGamingDate
        , datediff(day, MaxGamingDate, current_date()) as DaysSinceLastVisit
        , sum(pd.SlotTheoWinNetFreeplayInt100 + pd.TableTheoWinNetPromoCreditInt100)*.01 as NetTheo 
        , sum(pd.SlotActualWinNetFreeplayInt100 + pd.TableActualWinNetPromoCreditInt100)*.01 as NetActual
        , round(median(pd.SlotTheoWinNetFreeplayInt100 + pd.TableTheoWinNetPromoCreditInt100)*.01,2) as MedianDailyTheo
        , round((NetTheo/NumVisits),2) as AverageDailyTheo
    from playerinfo pi
    left join prod_core.qcids.fact_playerday pd 
        on pi.PlayerID = pd.PlayerID 
    where pi.Hosted = 0                                         -- unhosted players only
        and pd.TotalVisit = 1 
        and pd.GamingDate >= dateadd(month, -6, current_date()) -- last 6 months only
    group by 1, 2, 3, 4, 5
)
, filtering as (
-- include only players with ADT >= 400
    select * 
    from last6months
    where AverageDailyTheo >= 400
    order by AverageDailyTheo desc
)
select * from filtering
 