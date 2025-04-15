-- cohort analysis - signups 2022 and earlier

with month_metrics as
(select pd.CasinoID
  , pd.PlayerID
  , date_trunc('MONTH',SetupDate) SetupMonth
  , date_trunc('MONTH', GamingDate) GamingMonth
  , sum(cast(SlotCoinInInt100 as int) + cast(TableBetAmountInt100 as int))*.01 CoinIn
  , sum(SlotActualWinWithFreeplayInt100 + TableActualWinWithPromoCreditInt100)*.01 GrossActualWin
  , sum(SlotTheoWinWithFreeplayInt100 + TableTheoWinWithPromoCreditInt100)*.01 GrossTheoWin
  , sum(SlotFreeplayInt100 + TablePromoCreditInt100)*.01 Freeplay
  , sum(SlotActualWinNetFreeplayInt100 + TableActualWinNetPromoCreditInt100)*.01 NetActualWin
  , sum(SlotTheoWinNetFreeplayInt100 + TableTheoWinNetPromoCreditInt100)*.01 NetTheoWin
  from (select * from prod_core.qcids.Fact_PlayerDay where TotalVisit = 1) pd
  inner join (select PlayerID, SetupDate from prod_core.qcids.Dim_Player_SCD where IsCurrent = 1 and IsBanned = 0
            and SetupDate < '2022-01-01'
            and SetupDate > '2000-07-01' -- exclude bad data, roughly 0.9% of pre-2022 signups
            and SetupDate is not null) p on pd.PlayerID = p.PlayerID
  group by 1,2,3,4)

, full_cohort as (
  select SetupCasinoID
    , date_trunc('MONTH',SetupDate) SetupMonth
    , count(distinct PlayerID) cohort_size
    from prod_core.qcids.Dim_Player_SCD 
    where IsCurrent = 1 
        and SetupDate < '2022-01-01'
        and SetupDate > '2000-07-01' -- exclude bad data, roughly 0.9% of pre-2022 signups
        and SetupDate is not null and IsBanned = 0
    group by 1,2
)

select a.CasinoID
    , a.SetupMonth
    , date_diff(MONTH, a.SetupMonth, GamingMonth) months_from_setup
    , cohort_size
    , count(distinct PlayerID) players_active
    , sum(CoinIn) coinin
    , sum(GrossActualWin) grossactualwin
    , sum(GrossTheoWin) grosstheowin
    , sum(Freeplay) freeplay
    , sum(NetActualWin) netactualwin
    , sum(NetTheoWin) nettheowin
from month_metrics a
  left join full_cohort b on a.SetupMonth = b.SetupMonth and a.CasinoID = b.SetupCasinoID
where GamingMonth >= a.SetupMonth
group by 1,2,3,4
order by 1,2,3