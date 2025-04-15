-- MGC Fuzzy Matching Unrated Players

-- join scratchpad data
with scratchpad_data as (
    select 

        t.`PRIMARY ID` as StreamlineID
        , coalesce(
                    t.Name_First 
                    , substring(p.Name, charindex(',', p.Name)+1, len(p.name))
                    , null
                  ) as FirstName
        , t.Name_Last as LastName
        , upper(t.Address) as Address
        , upper(t.city) as City
        , upper(t.state) as State 
        , left(trim(t.zip_5),5) as Zip
        , t.Last_Day as StreamlineLastDay

        , p.WAGER_POINTS as WagerPoints
        , p.total_points as TotalPoints
        , p.points_used as PointsUsed
        , p.points_available as PointsAvailable

    from polaris_scratchpad.gaming_marketing.streamline_player_last_trip t
    left join polaris_scratchpad.gaming_marketing.streamline_player_point_liability p
        on t.`PRIMARY ID` = p.PRIMARY_ID
    where t.`PRIMARY ID` not in ('5000280') -- test ids, dummy ids

)

-- map scratchpad data to dim_player_scd
, mapping as (
    select

        s.StreamlineID   
        , d.PlayerID 
        , d.isCurrent
        , s.Address
        , s.City
        , s.State
        , d.HomeEmail as Email

        , s.StreamlineLastDay
    
        , coalesce( 
                    upper(d.LastName) 
                    , upper(s.LastName)
                    , null
                    ) as LastName
        , coalesce(
                    upper(d.FirstName) 
                    , upper(s.FirstName)
                    , null
                    )as FirstName
        , left(d.PlayerID, 3) as SetupCasinoID
        , d.Birthdate
        , coalesce (
                    left(d.HomePostalCode, 5) 
                    , s.Zip
                    , null
                    ) as Zipcode
        
        , s.WagerPoints 
        , s.TotalPoints 
        , s.PointsUsed 
        , s.PointsAvailable

    from scratchpad_data s 
    left join (
               select * -- limit to current accounts from MGC
               from prod_core.qcids.dim_player_scd
               where IsCurrent = 1 
               and SetupCasinoID = 'MGC'
               ) d -- Fuzzy Matching on First Name, Last Name, and Zip
        on trim(lower(s.FirstName)) = trim(lower(d.FirstName)) 
        and lower(s.LastName) = lower(d.LastName)
        and try_cast(s.Zip as int) = try_cast(left(d.homepostalcode, 5) as int)
        -- and try_cast(substr(m.DOB, -4)||'-'||substr(m.DOB, 1, 2)||'-'||substr(m.DOB, 3, 2) as date) = d.BirthDate
)

-- April 1 2024 - March 31 2025 get basic metrics 
, bet_metrics as (
  select 
      -- player data
      m.StreamlineID 
      , m.PlayerID 
      , m.FirstName
      , m.LastName
      , m.SetupCasinoID 
      , m.Birthdate 
      , datediff(year, m.Birthdate, current_date()) as Age
      , m.Address
      , m.City
      , m.State
      , m.Zipcode 
      , m.Email
      , substr(d.PlayerDistanceToCasino, 0, instr(d.PlayerDistancetoCasino, '.')+2) as DistanceToCasino -- truncate number to two decimal places

      , m.StreamlineLastDay 
      , datediff(day, m.StreamlineLastDay, current_date()) as DaysSinceStreamlineLastDay
      , LastDay
      , datediff(day, LastDay, current_date()) as DaysSinceGamingLastDay


      , m.WagerPoints 
      , m.TotalPoints 
      , m.PointsUsed
      , m.PointsAvailable

      -- basic metrics calculation
      , NumVisits
      , GrossTheo
      , GrossActual
      , Freeplay
      , NetTheo
      , NetActual

      , ADT
      , MDT
      , ADA
      , ADW

  from mapping m

  left join ( -- limit to dates in the last year
            select PlayerID
                  -- basic metrics calculation
                , sum(TotalVisit) as NumVisits
                , sum(SlotTheoWinWithFreeplayInt100 + TableTheoWinwithPromoCreditInt100)*.01 as GrossTheo
                , sum(SlotActualWinwithFreeplayInt100 + TableActualWinwithPromoCreditInt100)*.01 as GrossActual
                , sum(SlotFreeplayInt100 + TablePromoCreditInt100)*.01 as Freeplay
                , sum(SlotTheoWinNetFreeplayInt100 + TableTheoWinNetPromoCreditInt100)*.01 as NetTheo
                , sum(SlotActualWinNetFreeplayInt100 + TableActualWinNetPromoCreditInt100)*.01 as NetActual

                , round(try_divide(NetTheo, NumVisits), 2) as ADT
                , median(SlotTheoWinNetFreeplayInt100 + TableTheoWinNetPromoCreditInt100)*.01 as MDT
                , round(try_divide(NetActual, NumVisits), 2) as ADA
                , round(iff(ADT > ADA*0.4, ADT, ADA*0.4), 2) as ADW
            from prod_core.qcids.fact_playerday 
            where cast(GamingDate as date) >= '2024-04-01'
            and cast(GamingDate as date) <= '2025-03-31'
            and CasinoID = 'MGC'
            group by 1
            ) r
      on m.PlayerID = r.PlayerID

  left join ( -- no limit to date to calculate max(gamingDate)
            select PlayerID
                , max(cast(GamingDate as date)) as LastDay
            from prod_core.qcids.fact_playerday 
            where CasinoID = 'MGC'
            group by 1
            ) x
      on m.PlayerID = x.PlayerID

  left join  ( -- distance to MGC
            select distinct
                left(p.HomePostalCode, 5) as Zip
                , d.PlayerDistanceToCasino
            from (select * 
                  from prod_core.qcids.Dim_PlayerDistanceToCasino_SCD
                  where CasinoID = 'MGC' 
                    and IsCurrent = 1)  d
            left join (select * 
                       from prod_core.qcids.dim_player_scd
                       where IsCurrent = 1) p
                on d.PlayerID = p.PlayerID
             ) d
      on m.Zipcode = d.Zip
)

select *
from bet_metrics
order by TotalPoints desc