-- GCC YOY, MOM player level

with raw_data as (
  select 
      d.SetupCasinoID as CasinoID
      , p.PlayerID
      , l.LoyaltyCardLevel as Tier
      , l.IsCurrent
      , date_part('year', cast(p.GamingDate as date)) as TimePeriod

      -- host status
      , case when h.PlayerID is not null then 1 else 0 end as Hosted

      , cast(p.GamingDate as date)
      , p.TotalVisit

      -- coin in / table drop
      , p.SlotCoinInInt100::int
      , p.TableBetAmountInt100::int
      
      -- GrossTheoWin
      , p.SlotTheoWinWithFreeplayInt100
      , p.TableTheoWinwithPromoCreditInt100

      -- GrossActualWin
      , p.SlotActualWinwithFreeplayInt100
      , p.TableActualWinwithPromoCreditInt100

      -- Freeplay
      , p.SlotFreeplayInt100 
      , p.TablePromoCreditInt100

      -- NetTheoWin
      , p.SlotTheoWinNetFreeplayInt100
      , p.TableTheoWinNetPromoCreditInt100

      -- NetActualWin
      , p.SlotActualWinNetFreeplayInt100
      , p.TableActualWinNetPromoCreditInt100

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
      and d.SetUpCasinoID = 'GCC'
      and d.IsCurrent = 1            -- with most current banned status
      and d.IsBanned = 0             -- not banned
      and l.IsCurrent = 1            -- their current loyalty level
      and ((cast(GamingDate as date) >= '2024-02-01' and cast(GamingDate as date) <= '2024-03-10') or (cast(GamingDate as date) >= '2025-02-01' and cast(GamingDate as date) <= '2025-03-09'))  -- Feb-March 2024 + Feb-March 2025
)

-- aggregate & segment players for 2024 time period
, first_aggie as (
  select
      r.PlayerID
      , r.TimePeriod
      , r.Tier
      , r.Hosted

      , sum(r.TotalVisit) as NumVisits

      -- slot metrics
      , sum(r.SlotCoinInInt100)*.01 as CoinIn
      , sum(r.SlotTheoWinWithFreeplayInt100)*.01 as SlotsGrossTheo
      , sum(r.SlotActualWinwithFreeplayInt100)*.01 as SlotsGrossActual
      , sum(r.SlotFreeplayInt100)*.01 as SlotsFreeplay
      , sum(r.SlotTheoWinNetFreeplayInt100)*.01 as SlotsNetTheo
      , sum(r.SlotActualWinNetFreeplayInt100)*.01 as SlotsNetActual

      -- table metrics metrics calculation
      , sum(r.TableBetAmountInt100)*.01 as TableDrop
      , sum(r.TableTheoWinwithPromoCreditInt100)*.01 as TableGrossTheo
      , sum(r.TableActualWinwithPromoCreditInt100)*.01 as TableGrossActual
      , sum(r.TablePromoCreditInt100)*.01 as TableFreeplay
      , sum(r.TableTheoWinNetPromoCreditInt100)*.01 as TableNetTheo
      , sum(r.TableActualWinNetPromoCreditInt100)*.01 as TableNetActual

      -- combined metrics calculation
      , sum(r.SlotCoinInInt100 + r.TableBetAmountInt100)*.01 as TotalCoinIn
      , sum(r.SlotTheoWinWithFreeplayInt100 + r.TableTheoWinwithPromoCreditInt100)*.01 as GrossTheo
      , sum(r.SlotActualWinwithFreeplayInt100 + r.TableActualWinwithPromoCreditInt100)*.01 as GrossActual
      , sum(r.SlotFreeplayInt100 + r.TablePromoCreditInt100)*.01 as Freeplay
      , sum(r.SlotTheoWinNetFreeplayInt100 + r.TableTheoWinNetPromoCreditInt100)*.01 as NetTheo
      , sum(r.SlotActualWinNetFreeplayInt100 + r.TableActualWinNetPromoCreditInt100)*.01 as NetActual

      -- GrossADW calculation
      , case when (GrossTheo/NumVisits) > ((GrossActual/NumVisits)*0.4) then round((GrossTheo/NumVisits),2)
             else round(((GrossActual/NumVisits)*0.4),2) end
             as GrossADW

      -- GrossADW segmentation
      , case													
          when GrossADW >= 2000                     then '2000+'													
          when GrossADW >= 1500 and GrossADW < 2000 then '1500 - 1999'													
          when GrossADW >= 1200 and GrossADW < 1500 then '1200 - 1499'													
          when GrossADW >=  900 and GrossADW < 1200 then  '900 - 1199'													
          when GrossADW >=  700 and GrossADW <  900 then  '700 - 899'													
          when GrossADW >=  575 and GrossADW <  700 then  '575 - 699'													
          when GrossADW >=  475 and GrossADW <  575 then  '475 - 574'													
          when GrossADW >=  400 and GrossADW <  475 then  '400 - 474'													
          when GrossADW >=  350 and GrossADW <  400 then  '350 - 399'													
          when GrossADW >=  300 and GrossADW <  350 then  '300 - 349'													
          when GrossADW >=  260 and GrossADW <  300 then  '260 - 299'													
          when GrossADW >=  230 and GrossADW <  260 then  '230 - 259'													
          when GrossADW >=  200 and GrossADW <  230 then  '200 - 229'													
          when GrossADW >=  175 and GrossADW <  200 then  '175 - 199'													
          when GrossADW >=  150 and GrossADW <  175 then  '150 - 174'													
          when GrossADW >=  125 and GrossADW <  150 then  '125 - 149'													
          when GrossADW >=  100 and GrossADW <  125 then  '100 - 124'													
          when GrossADW >=   75 and GrossADW <  100 then   '75 - 99'													
          when GrossADW >=   50 and GrossADW <   75 then   '50 - 74'													
          when GrossADW >=   25 and GrossADW <   50 then   '25 - 49'													
          else 'Below 25'													
      end as Segment	
      
      , case													
          when Segment = '2000+'       then 1												
          when Segment = '1500 - 1999' then 2												
          when Segment = '1200 - 1499' then 3												
          when Segment = '900 - 1199'	 then 4											
          when Segment = '700 - 899'   then 5												
          when Segment = '575 - 699'   then 6												
          when Segment = '475 - 574'   then 7												
          when Segment = '400 - 474'   then 8													
          when Segment = '350 - 399'   then 9												
          when Segment = '300 - 349'   then 10												
          when Segment = '260 - 299'   then 11													
          when Segment = '230 - 259'   then 12											
          when Segment = '200 - 229'   then 13											
          when Segment = '175 - 199'   then 14												
          when Segment = '150 - 174'   then 15											
          when Segment = '125 - 149'   then 16												
          when Segment = '100 - 124'   then 17											
          when Segment = '75 - 99'	   then 18												
          when Segment = '50 - 74'     then 19									
          when Segment = '25 - 49'	   then 20												
          when Segment = 'Below 25'	   then 21											
      end as SegmentNumber
      	
      
  from raw_data r
  where cast(GamingDate as date) >= '2024-02-01' 
    and cast(GamingDate as date) < '2024-04-01'
  group by r.PlayerID, TimePeriod, r.Tier, r.Hosted
)

-- aggregate & segment players for 2025 time period
, second_aggie as (
  select
      r.PlayerID
      , r.TimePeriod
      , r.Tier
      , r.Hosted

      , sum(r.TotalVisit) as NumVisits

      -- slot metrics
      , sum(r.SlotCoinInInt100)*.01 as CoinIn
      , sum(r.SlotTheoWinWithFreeplayInt100)*.01 as SlotsGrossTheo
      , sum(r.SlotActualWinwithFreeplayInt100)*.01 as SlotsGrossActual
      , sum(r.SlotFreeplayInt100)*.01 as SlotsFreeplay
      , sum(r.SlotTheoWinNetFreeplayInt100)*.01 as SlotsNetTheo
      , sum(r.SlotActualWinNetFreeplayInt100)*.01 as SlotsNetActual

      -- table metrics metrics calculation
      , sum(r.TableBetAmountInt100)*.01 as TableDrop
      , sum(r.TableTheoWinwithPromoCreditInt100)*.01 as TableGrossTheo
      , sum(r.TableActualWinwithPromoCreditInt100)*.01 as TableGrossActual
      , sum(r.TablePromoCreditInt100)*.01 as TableFreeplay
      , sum(r.TableTheoWinNetPromoCreditInt100)*.01 as TableNetTheo
      , sum(r.TableActualWinNetPromoCreditInt100)*.01 as TableNetActual

      -- combined metrics calculation
      , sum(r.SlotCoinInInt100 + r.TableBetAmountInt100)*.01 as TotalCoinIn
      , sum(r.SlotTheoWinWithFreeplayInt100 + r.TableTheoWinwithPromoCreditInt100)*.01 as GrossTheo
      , sum(r.SlotActualWinwithFreeplayInt100 + r.TableActualWinwithPromoCreditInt100)*.01 as GrossActual
      , sum(r.SlotFreeplayInt100 + r.TablePromoCreditInt100)*.01 as Freeplay
      , sum(r.SlotTheoWinNetFreeplayInt100 + r.TableTheoWinNetPromoCreditInt100)*.01 as NetTheo
      , sum(r.SlotActualWinNetFreeplayInt100 + r.TableActualWinNetPromoCreditInt100)*.01 as NetActual

      -- GrossADW calculation
      , case when try_divide(GrossTheo,NumVisits) > (try_divide(GrossActual,NumVisits)*0.4) then round(try_divide(GrossTheo,NumVisits),2)
             else round((try_divide(GrossActual,NumVisits)*0.4),2) end
             as GrossADW

      -- GrossADW segmentation
      , case													
          when GrossADW >= 2000                     then '2000+'													
          when GrossADW >= 1500 and GrossADW < 2000 then '1500 - 1999'													
          when GrossADW >= 1200 and GrossADW < 1500 then '1200 - 1499'													
          when GrossADW >=  900 and GrossADW < 1200 then  '900 - 1199'													
          when GrossADW >=  700 and GrossADW <  900 then  '700 - 899'													
          when GrossADW >=  575 and GrossADW <  700 then  '575 - 699'													
          when GrossADW >=  475 and GrossADW <  575 then  '475 - 574'													
          when GrossADW >=  400 and GrossADW <  475 then  '400 - 474'													
          when GrossADW >=  350 and GrossADW <  400 then  '350 - 399'													
          when GrossADW >=  300 and GrossADW <  350 then  '300 - 349'													
          when GrossADW >=  260 and GrossADW <  300 then  '260 - 299'													
          when GrossADW >=  230 and GrossADW <  260 then  '230 - 259'													
          when GrossADW >=  200 and GrossADW <  230 then  '200 - 229'													
          when GrossADW >=  175 and GrossADW <  200 then  '175 - 199'													
          when GrossADW >=  150 and GrossADW <  175 then  '150 - 174'													
          when GrossADW >=  125 and GrossADW <  150 then  '125 - 149'													
          when GrossADW >=  100 and GrossADW <  125 then  '100 - 124'													
          when GrossADW >=   75 and GrossADW <  100 then   '75 - 99'													
          when GrossADW >=   50 and GrossADW <   75 then   '50 - 74'													
          when GrossADW >=   25 and GrossADW <   50 then   '25 - 49'													
          else 'Below 25'													
      end as Segment	
      
      , case													
          when Segment = '2000+'       then 1												
          when Segment = '1500 - 1999' then 2												
          when Segment = '1200 - 1499' then 3												
          when Segment = '900 - 1199'	 then 4											
          when Segment = '700 - 899'   then 5												
          when Segment = '575 - 699'   then 6												
          when Segment = '475 - 574'   then 7												
          when Segment = '400 - 474'   then 8													
          when Segment = '350 - 399'   then 9												
          when Segment = '300 - 349'   then 10												
          when Segment = '260 - 299'   then 11													
          when Segment = '230 - 259'   then 12											
          when Segment = '200 - 229'   then 13											
          when Segment = '175 - 199'   then 14												
          when Segment = '150 - 174'   then 15											
          when Segment = '125 - 149'   then 16												
          when Segment = '100 - 124'   then 17											
          when Segment = '75 - 99'	   then 18												
          when Segment = '50 - 74'     then 19									
          when Segment = '25 - 49'	   then 20												
          when Segment = 'Below 25'	   then 21											
      end as SegmentNumber
      	
      
  from raw_data r
  where cast(GamingDate as date) >= '2025-02-01' 
    and cast(GamingDate as date) < '2025-04-01'
  group by r.PlayerID, TimePeriod, r.Tier, r.Hosted
)

-- combine first and second aggies
, combined as (
  select * from first_aggie 
  union all
  select * from second_aggie
)

select 
     TimePeriod
     , SegmentNumber
     , count(PlayerID) as NumPlayers

     -- slot metrics
     , sum(CoinIn) as CoinIn
     , sum(SlotsGrossTheo) as SlotsGrossTheo
     , sum(SlotsGrossActual) as SlotsGrossActual
     , sum(SlotsFreeplay) as SlotsFreeplay
     , sum(SlotsNetTheo) as SlotsNetTheo
     , sum(SlotsNetActual) as SlotsNetActual

     -- table metrics
     , sum(TableDrop) as TableDrop
     , sum(TableGrossTheo) as TableGrossTheo 
     , sum(TableGrossActual) as TableGrossActual
     , sum(TableFreeplay) as TableFreeplay
     , sum(TableNetTheo) as TableNetTheo 
     , sum(TableNetActual) as TableNetActual

     -- total metrics
     , sum(TotalCoinIn) as TotalBetAmount
     , sum(GrossTheo) as GrossTheo
     , sum(GrossActual) as GrossActual
     , sum(Freeplay) as Freeplay
     , sum(NetTheo) as NetTheo
     , sum(NetActual) as NetActual 

from combined 
group by 1,2 
order by SegmentNumber asc, TimePeriod
