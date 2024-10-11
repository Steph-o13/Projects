-- user_interests_sports

-- calculate num_bets, active days, handle by user and sport
with bet_sports as (select b.user_id
                         , m.sport_name
                         , count(distinct b.id)                                            as num_bet
                         , count(distinct l.id)                                            as num_legs
                         , trunc(count(distinct l.id) * 1.0 / count(distinct b.id), 2)     as avg_legs
                         , count(distinct trunc(date_trunc('day', b.placed_at)))           as num_active_days
                         , avg(trunc(l.decimal_odds_leg, 8))                               as decimal_odds
                         , sum(b.wagered_cash + b.wagered_free + b.wagered_credits)::float as bet_dollars
                    from {{ source('aec', 'fct_edgebook_usd_bet_legs') }}  l
                             inner join {{ source('aec', 'dim_vegas_markets') }} m
                                        on l.market_id = m.id
                             inner join {{ source('aec', 'fct_edgebook_usd_bets') }} b
                                        on b.id = l.bet_id
                             inner join {{ source('aec', 'dim_identity_users') }} d
                                        on b.user_id = d.id
                    where b.placed_at >= dateadd(day, -365, current_date)
                      and (b.wagered_cash + b.wagered_free + b.wagered_credits)::float >= 1.0
                      and b.country = 'CA'
                      and d.is_tester = false
                    group by 1, 2

                    union all

                    select b.user_id
                         , m.sport_name
                         , count(distinct b.id)                                            as num_bet
                         , count(distinct l.id)                                            as num_legs
                         , trunc(count(distinct l.id) * 1.0 / count(distinct b.id), 2)     as avg_legs
                         , count(distinct trunc(date_trunc('day', b.placed_at)))           as num_active_days
                         , avg(trunc(l.decimal_odds_leg, 8))                               as decimal_odds
                         , sum(b.wagered_cash + b.wagered_free + b.wagered_credits)::float as bet_dollars
                    from {{ source('aec', 'fct_edgebook_usd_bet_legs') }}  l
                             inner join {{ source('aec', 'dim_vegas_markets') }} m
                                        on l.market_id = m.id
                             inner join {{ source('aec', 'fct_edgebook_usd_bets') }} b
                                        on b.id = l.bet_id
                             inner join {{ source('aec', 'dim_identity_users') }} d
                                        on b.user_id = d.id
                    where b.placed_at >= dateadd(day, -365, current_date)
                      and b.placed_at >= '2023-07-10 00:00:00'
                      -- BSSB historical data is not reliable before July 10, 2023
                      and (b.wagered_cash::float + b.wagered_free::float + b.wagered_credits) >= 1.0
                      and b.country = 'US'
                      and d.is_tester = false
                    group by 1, 2)

-- calculate num_bets, active days, handle by user
   , user_bets as (select b.user_id
                        , count(distinct b.id)                                            as num_bet
                        , count(distinct trunc(date_trunc('day', b.placed_at)))           as num_active_days
                        , sum(b.wagered_cash + b.wagered_free + b.wagered_credits)::float as bet_dollars
                   from {{ source('aec', 'fct_edgebook_usd_bet_legs') }}  l
                            inner join {{ source('aec', 'dim_vegas_markets') }} m
                                       on l.market_id = m.id
                            inner join {{ source('aec', 'fct_edgebook_usd_bets') }} b
                                       on b.id = l.bet_id
                            inner join {{ source('aec', 'dim_identity_users') }} d
                                       on b.user_id = d.id
                   where b.placed_at >= dateadd(day, -365, current_date)
                     and (b.wagered_cash::float + b.wagered_free::float + b.wagered_credits) >= 1.0
                     and b.country = 'CA'
                     and d.is_tester = false
                   group by 1

                   union all

                   select b.user_id
                        , count(distinct b.id)                                            as num_bet
                        , count(distinct trunc(date_trunc('day', b.placed_at)))           as num_active_days
                        , sum(b.wagered_cash + b.wagered_free + b.wagered_credits)::float as bet_dollars
                   from {{ source('aec', 'fct_edgebook_usd_bet_legs') }}  l
                            inner join {{ source('aec', 'dim_vegas_markets') }} m
                                       on l.market_id = m.id
                            inner join {{ source('aec', 'fct_edgebook_usd_bets') }} b
                                       on b.id = l.bet_id
                            inner join {{ source('aec', 'dim_identity_users') }} d
                                       on b.user_id = d.id
                   where b.placed_at >= dateadd(day, -365, current_date)
                     and b.placed_at >= '2023-07-10 00:00:00'
                     -- BSSB historical data is not reliable before July 10, 2023
                     and (b.wagered_cash::float + b.wagered_free::float + b.wagered_credits) >= 1.0
                     and b.country = 'US'
                     and d.is_tester = false
                   group by 1)

-- calculate bet score, active day score, handle score by user
   , final as (select ub.user_id
                    , bs.sport_name
                    , bs.avg_legs
                    , bs.decimal_odds
                    , bs.bet_dollars
                    , bs.num_bet
                    , ub.num_bet                                              as total_bets
                    , bs.num_active_days
                    , case
                          when bs.decimal_odds >= 2.0 then round((bs.decimal_odds - 1) * 100, 0)
                          else round(-100 / (bs.decimal_odds - 1), 0) end     as american_odds
                    , (bs.num_bet::float / ub.num_bet::float)                 as bet_score
                    , (bs.num_active_days::float / ub.num_active_days::float) as active_score
                    , (bs.bet_dollars / ub.bet_dollars)                       as handle_score
                    , bet_score + active_score + handle_score                 as raw_interest_score
                    , sum(raw_interest_score) over (partition by ub.user_id)  as sum_score
               from user_bets ub
                        left join bet_sports bs
                                  on bs.user_id = ub.user_id)
-- normalize interest score
   , aggie as (select user_id
                    , sport_name                                                            as sport
                    , avg_legs
                    , decimal_odds
                    , american_odds
                    , bet_dollars
                    , trunc(raw_interest_score / sum_score, 4)                              as interest_score
                    , dense_rank() over (partition by user_id order by interest_score desc) as interest_rank
               from final f)

-- calculate global popularity of sports overall by total interest_score
   , global_ranking as (select sport,
                               sum(interest_score)                              as total_interest,
                               row_number() over (order by total_interest desc) as global_rank
                        from aggie
                        group by sport)

-- in cases of ties, order the tied sports by global popularity
   , tiebreaker as (select a.user_id
                         , a.sport
                         , a.avg_legs
                         , a.decimal_odds
                         , a.american_odds
                         , a.bet_dollars
                         , a.interest_score
                         -- if there is a tie in the user's interest_rank, order the tied categories by interest_rank and global_rank
                         , dense_rank() over (partition by a.user_id order by a.interest_rank, g.global_rank) as interest_rank
                    from aggie a
                             left join global_ranking g
                                       on g.sport = a.sport)
select *
from tiebreaker
