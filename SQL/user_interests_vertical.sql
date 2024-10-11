--user_interests_vertical

with raw_bets -- get all sbk and casino bets from the last year
    as (select c.user_id
             , c.id                            as bet_id
             , c.country
             , c.region
             , c.wagered_at                    as utc_placed_date
             , c.wagered_free + c.wagered_cash as handle
             , 'casino'                        as vertical
        from {{ source('aec', 'fct_edgebook_usd_casino_wagers') }} c
                 inner join {{ source('aec', 'dim_identity_users') }} d
                            on c.user_id = d.id
        where c.wagered_at >= dateadd(day, -365, current_date)
          and d.is_tester = false

        union all

        select b.user_id
             , b.id                                                as bet_id
             , b.country
             , b.region
             , b.placed_at                                         as utc_placed_date
             , b.wagered_free + b.wagered_cash + b.wagered_credits as handle
             , 'sportsbook'                                        as vertical
        from {{ source('aec', 'fct_edgebook_usd_bets') }} b
                 inner join {{ source('aec', 'dim_identity_users') }} d
                            on b.user_id = d.id
        where b.placed_at >= dateadd(day, -365, current_date)
          and d.is_tester = false)

   , all_bets -- calculate timezones, local time, hour of day
    as (select user_id
             , bet_id
             , country
             , region
             , utc_placed_date
             , handle
             , vertical
             , case
                   when region in ('AZ', 'CO', 'ID', 'MT', 'NM', 'UT', 'WY', 'YT', 'NT', 'AB')
                       then 'MST'
                   when region in
                        ('AL', 'AR', 'IL', 'IA', 'KS', 'LA', 'MN', 'MS', 'MO', 'NE', 'ND', 'OK',
                         'SD', 'TX', 'WI', 'SK', 'MB') then 'CST'
                   when region in
                        ('CT', 'DE', 'DC', 'FL', 'GA', 'IN', 'KY', 'ME', 'MD', 'MA', 'MI', 'NH',
                         'NJ', 'NY', 'NC', 'OH', 'PA', 'RI', 'SC', 'TN', 'VT', 'VA', 'WV', 'ON',
                         'NU', 'QC', 'NB') then 'EST'
                   when region in ('CA', 'NV', 'OR', 'WA', 'BC') then 'PST'
                   when region in ('HI') then 'HST'
                   when region in ('AK') then 'AKT'
                   when region in ('NS', 'PE') then 'ADT'
                   when region in ('NF') then 'NDT'
                   else 'OTHER'
            end                                  as timezone
             -- IGNORING DAYLIGHT SAVINGS TIME
             , case
                   when timezone = 'HST' then dateadd(hour, -10, utc_placed_date)
                   when timezone = 'AKT' then dateadd(hour, -9, utc_placed_date)
                   when timezone = 'PST' then dateadd(hour, -8, utc_placed_date)
                   when timezone = 'MST' then dateadd(hour, -7, utc_placed_date)
                   when timezone = 'CST' then dateadd(hour, -6, utc_placed_date)
                   when timezone = 'EST' then dateadd(hour, -5, utc_placed_date)
                   when timezone = 'ADT' then dateadd(hour, -4, utc_placed_date)
                   when timezone = 'NDT' then dateadd(hour, -3, utc_placed_date)
                   else null
            end                                  as local_placed_date
             , datepart(HOUR, local_placed_date) as local_bet_hour
             , case
                   when local_bet_hour between 0 and 6 then 'night'
                   when local_bet_hour between 6 and 12 then 'morning'
                   when local_bet_hour between 12 and 18 then 'afternoon'
                   when local_bet_hour between 18 and 24 then 'evening'
                   else NULL
            end                                  as time_category
        from raw_bets)

   , region_calc -- calculate region ranks per vertical
    as (select user_id
             , vertical
             , region
             , count(distinct trunc(date_trunc('day', utc_placed_date)))       as num_days -- count by distinct days rather than number of bets.
             , row_number() over (partition by user_id order by num_days desc) as region_rank
        from all_bets
        group by 1, 2, 3)

   , dom_region_calc -- get the dominant region per vertical
    as (select r1.user_id
             , r1.vertical
             , r1.region
        from region_calc r1
                 join (select r.user_id, r.vertical, min(r.region_rank) as min_rank
                       from region_calc r
                       group by 1, 2) r2
                      on r1.user_id = r2.user_id and r1.vertical = r2.vertical and r1.region_rank = r2.min_rank)

   , time_cat_calc -- calculate the ranks of time_category per vertical
    as (select user_id
             , vertical
             , time_category
             , count(distinct trunc(date_trunc('day', utc_placed_date)))       as num_days -- count by distinct days rather than number of bets.
             , row_number() over (partition by user_id order by num_days desc) as time_rank
        from all_bets
        group by 1, 2, 3)

   , dom_time_cat_calc -- get the dominant time category per vertical
    as (select t1.user_id
             , t1.vertical
             , t1.time_category
        from time_cat_calc t1
                 join (select t.user_id, t.vertical, min(t.time_rank) as min_rank
                       from time_cat_calc t
                       group by 1, 2) t2
                      on t1.user_id = t2.user_id and t1.vertical = t2.vertical and t1.time_rank = t2.min_rank)

   , vertical_bets -- calculate basic sbk and casino stats needed for numerator of interest_score
    as (select user_id
             , vertical
             , count(bet_id)                                             as num_bets -- get number of bets placed by user and vertical
             , count(distinct trunc(date_trunc('day', utc_placed_date))) as num_days
             , sum(handle)::float                                        as total_handle
             , avg(handle)::float                                        as avg_handle
        from all_bets
        group by 1, 2)

   , bets -- calculate overall stats needed for denominator of interest_score
    as (select user_id
             , count(distinct trunc(date_trunc('day', utc_placed_date))) as num_days
             , sum(handle)::float                                        as total_handle
             , avg(handle)::float                                        as avg_handle
        from all_bets
        group by 1)

   , bet_counts -- get the bet counts for both verticals
       as (select user_id
                  , max(num_bets) as max_bets
                  , min(num_bets) as min_bets
        from vertical_bets
        group by 1)

   , interest_calculation -- calculate interest scores for casino and sbk
    as (select v.user_id
             , v.vertical
             , v.num_bets
             , t.time_category
             , r.region
             , v.avg_handle

             , isnull(v.total_handle, 0)::float                      as total_bet_dollars
             , isnull(v.num_days, 0)::float                          as total_active_days

             , (v.num_days / b.num_days::float)                      as active_score
             , (v.total_handle / b.total_handle)                     as handle_score
             , active_score + handle_score                           as raw_interest_score
             , sum(raw_interest_score) over (partition by v.user_id) as sum_score
        from vertical_bets v
                 join bets b
                      on v.user_id = b.user_id
                 left join dom_time_cat_calc t
                           on v.user_id = t.user_id and v.vertical = t.vertical
                 left join dom_region_calc r
                           on v.user_id = r.user_id and v.vertical = r.vertical)

   , normalized_score -- normalize each player's score
    as (select user_id
             , vertical
             , num_bets
             , time_category
             , region
             , avg_handle
             , trunc(raw_interest_score / sum_score, 5)                              as interest_score
             , row_number() over (partition by user_id order by interest_score desc) as interest_rank -- rn to force uniqueness
        from interest_calculation
        where interest_score <> 0 -- remove any rows with verticals for players who don't play that vertical
    )

   , dominant_category -- calculate the dominant category (casino, sbk, multiproduct) per user
    -- multiproduct definition: at least 10 bets placed in both verticals and difference in interest_scores between verticals <= .20
    -- multiproduct = .50 interest score exactly
    -- multiproduct_cas/sbk = when interest score for rank 1 vertical between (.50,.60]
    as (select n.user_id
             , round(avg_handle,2) as avg_handle
             , n.num_bets
             , interest_score
             , interest_rank
             , case
                   when b.min_bets >= 10 and interest_score = .50 then 'multiproduct'
                   when b.min_bets >= 10 and vertical = 'sportsbook' and interest_score between .50 and .60 and interest_score <> .50
                       then 'multiproduct_sbk'
                   when b.min_bets >= 10 and vertical = 'casino' and interest_score between .50 and .60 and interest_score <> .50
                       then 'multiproduct_cas'
                   else vertical end as vertical -- calculate dominant category
             , time_category
             , region
        from normalized_score n
        left join bet_counts b
            on b.user_id = n.user_id
        where interest_rank = 1)

select *
from dominant_category
