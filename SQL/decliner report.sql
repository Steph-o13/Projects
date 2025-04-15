-- decliner report

with raw_data as (
  select 
      d.SetupCasinoID as CasinoID
      , p.PlayerID
      , d.SetupDate as SignupDate
      , l.LoyaltyCardLevel as Tier
      , cast(p.GamingDate as date)
      , p.TotalVisit

      -- host status
      , case when h.PlayerID is not null then 1 else 0 end as Hosted
      , concat(h.HostFirstName, " ", h.HostLastName) as HostName
      
      -- GrossTheoWin
      , p.SlotTheoWinWithFreeplayInt100
      , p.TableTheoWinwithPromoCreditInt100

      -- GrossActualWin
      , p.SlotActualWinwithFreeplayInt100
      , p.TableActualWinwithPromoCreditInt100

  from prod_core.qcids.fact_playerday p
  join prod_core.qcids.dim_player_scd d
      on d.PlayerID = p.PlayerID
  join prod_core.qcids.dim_playerloyalty_scd l
      on d.PlayerID = l.PlayerID
  left join (select e.*, d.PlayerID 
            from prod_core.qcids.dim_playerhost_SCD d
            left join prod_core.qcids.Dim_host_scd e 
              on d.HostID = e.HostID
            where d.IsCurrent = 1 and e.IsCurrent = 1) h
      on p.PlayerID = h.PlayerID

  where p.TotalVisit = 1             -- where player has played  
      and d.IsCurrent = 1            -- with most current banned status
      and l.IsCurrent = 1            -- their current loyalty level
      and d.IsBanned = 0             -- not banned
      and cast(GamingDate as date) >= dateadd(day, -61, current_date())
)

-- calculate the metrics for the first time period, the previous 30 days before the most recent 30 day prior to current date
, pre_period as (
    select 
      CasinoID 
      , PlayerID 
      , SignupDate 
      , Tier
      , Hosted 
      , HostName 

      -- metrics
      , sum(TotalVisit) as NumVisits
      , sum(SlotTheoWinWithFreeplayInt100 + TableTheoWinwithPromoCreditInt100)*.01 as GrossTheoWin
      , sum(SlotActualWinwithFreeplayInt100 + TableActualWinwithPromoCreditInt100)*.01 as GrossActualWin

      -- GrossADW
      , case when (GrossTheoWin/NumVisits) > ((GrossActualWin/NumVisits)*0.4) then round((GrossTheoWin/NumVisits),2)
             else round(((GrossActualWin/NumVisits)*0.4),2) end
             as GrossADW

    from raw_data
    where cast(GamingDate as date) < dateadd(day, -31 , current_date())  
      and cast(GamingDate as date) >= dateadd(day, -61 , current_date())  
    group by CasinoID, PlayerID, SignupDate, Tier, Hosted, HostName
)

-- calculate the metrics for the second time period, the 30 days rolling prior to current date
, post_period as (
    select 
      CasinoID 
      , PlayerID 
      , SignupDate 
      , Tier
      , Hosted 
      , HostName 

      , max(GamingDate) as MaxGamingDate

      -- metrics
      , sum(TotalVisit) as NumVisits
      , sum(SlotTheoWinWithFreeplayInt100 + TableTheoWinwithPromoCreditInt100)*.01 as GrossTheoWin
      , sum(SlotActualWinwithFreeplayInt100 + TableActualWinwithPromoCreditInt100)*.01 as GrossActualWin

      -- GrossADW
      , case when (GrossTheoWin/NumVisits) > ((GrossActualWin/NumVisits)*0.4) then round((GrossTheoWin/NumVisits),2)
             else round(((GrossActualWin/NumVisits)*0.4),2) end
             as GrossADW

    from raw_data
    where cast(GamingDate as date) >= dateadd(day, -31 , current_date())  
    group by CasinoID, PlayerID, SignupDate, Tier, Hosted, HostName
)

, calculations as (
    select 
      pre.CasinoID 
      , pre.PlayerID 
      , pre.SignupDate 
      , pre.Tier 
      , pre.Hosted 
      , pre.HostName 
      , post.MaxGamingDate
      , datediff(current_date(), post.MaxGamingDate) as DaysSinceLastPlay

      -- base metrics
      , post.GrossTheoWin as post_GrossTheoWin
      , pre.GrossTheoWin as pre_GrossTheoWin
      , post.GrossADW as post_GrossADW
      , pre.GrossADW as pre_GrossADW
      , post.NumVisits as post_NumVisits
      , pre.NumVisits as pre_NumVisits
      
      -- percent difference in theo from post to pre (post-pre / pre)
      , try_divide((post.GrossTheoWin-pre.GrossTheoWin),pre.GrossTheoWin) as PctDiff_GrossTheo

      -- percent difference in ADW from pre to post
      , try_divide((post.GrossADW-pre.GrossADW),pre.GrossADW) as PctDiff_GrossADW

      -- percent difference in number of visits from pre to post
      , try_divide((post.NumVisits-pre.NumVisits),pre.NumVisits) as PctDiff_NumVisits


    from pre_period pre
    join post_period post  
      on pre.PlayerID = post.PlayerID
    where pre.GrossADW >= 250           -- where pre GrossADW >= 250
    order by PctDiff_GrossTheo desc 
)

select * from calculations
