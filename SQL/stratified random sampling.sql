-- First and latest bet date for each user
WITH distinct_dates AS (SELECT DISTINCT placed_at::DATE              AS prediction_date
                                      , DATEPART(WEEKDAY, placed_at) AS day_of_week
                        FROM curated.aec.fct_edgebook_usd_bets
                        WHERE placed_at >= DATEADD(DAYS, -379, CURRENT_DATE) -- limit to previous 12 months of data, starting from 14 days ago
                          AND placed_at <= DATEADD(DAYS, -14, CURRENT_DATE)) -- don't include any dates in the most recent 14 days (needed for evaluation)

   -- randomly select X prediction dates for each day of the week
   , strat_sample as (select stratified_sample.*
                      from (select d.*
                                 , row_number() over (partition by day_of_week order by random()) as seqnum
                                 , count(*) over ()                                               as num_possible_pred_dates
                            from distinct_dates d) stratified_sample
                      where seqnum <= 12 -- 12 dates for each day_of_week
)

   , first_and_latest_bet_date AS (SELECT user_id
                                        , MIN(placed_at)::DATE AS first_bet_date
                                        , MAX(placed_at)::DATE AS latest_bet_date
                                   FROM curated.aec.fct_edgebook_usd_bets
                                   GROUP BY 1)

   -- use a cartesian join between all the randomly selected prediction dates and each user
   , stratified_first_and_latest_bet_date AS (SELECT f.user_id
                                                   , f.first_bet_date
                                                   , f.latest_bet_date
                                                   , s.prediction_date
                                              from first_and_latest_bet_date f
                                                       cross join strat_sample s)

   -- eliminate prediction dates that are before the user's first bet or too close to their most recent bet
   , users_prediction_dates AS (SELECT user_id
                                     , prediction_date
                                FROM stratified_first_and_latest_bet_date
                                WHERE prediction_date > first_bet_date
                                  AND prediction_date <= DATEADD(DAY, 31, latest_bet_date))
