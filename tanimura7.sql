----------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------- Experiment Analysis --------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- experimentation (A/B testing, split testing) is considering the gold standard of establishing causation
-- much of data analysis work involves establishing correlations
-- element 1: experiments begin with a hypothesis that a behavioral change will result from a change in product, process, message etc
-- ex user onboarding flow, algorithm for recommendations, marketing message and time, etc.
-- prior insights from data analysis workflow could drive a new hypothesis about causality
-- element 2: success metric that should quantify the behavioral change in question
-- success metric should be reasonable to measure and easy enough to detect
-- good success metrics are ones that you already track in your database
-- caution about establishing multiple success metrics
-- its harder to see significant change in one measure of success but easy if theres 20 measures of success, theres a good change one will show significance
-- rule of thumb is one or two primary success metrics
-- element 3: random assignment into control or experimental varient group (cohorting system)
-- experimentation in online systems differ from social science experiments in that the behaviors are already tracked
-- data profiling before the experiment is important to track down potential issues that could hamper your analysis results
------------------------------------------------ Strength Limits of Experiment Analysis with SQL ---------------------------------------------------------

-- relevant data already flows through the database so sql is convenient to use for experiementation 
-- success metrics are usually already defined in company vocabulation so preexisting queries likely already exist 
-- automating queries for experiments, allows for quick substitution of values to speed up querying process
-- main downside is sqls statistical limitations, unable to establish statistical significance
-- user defined functions (UDF) may be a way around this 

-- reasons for a correlation between x and y:
        -- x causes y
        -- y causes x
        -- something else causes x and y
        -- there is a feedback loop between x and y
        -- no relationship, its just random
        

---------------------------------------------------- Chi-Squared Test for Binary Outcomes ----------------------------------------------------------------

-- binary outcomes: either a action is taken or isn't
-- we can also calculate proportion of each group that completes action (completion rate, click-through rate, etc)
-- chi-squared test used to determine if theres a statistical difference, used for categorical and binary variables
-- output is a contingency table, looks like a pivot table

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- for the record all exp_name values in exp_assignment are 'Onboarding' in the table but we use a WHERE anyway
-- game_actions table has values 'email_optin' and 'onboarding complete' for action column 
-- heres a glimpse of the records before being aggregated
-- a left join here brings back all users from first table and only the users from joined table that have onboarding completed

SELECT
    a.variant,
    a.user_id,
    b.user_id
FROM exp_assignment a
LEFT JOIN game_actions b
  ON a.user_id = b.user_id
  AND b.action = 'onboarding complete'
WHERE a.exp_name = 'Onboarding'

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- output resembles a continguency table, pivoted
-- binary outcome experiments follow this basic pattern

SELECT
    a.variant,
    COUNT(CASE WHEN b.user_id IS NOT NULL THEN a.user_id END) AS completed,
    COUNT(CASE WHEN b.user_id IS NULL THEN a.user_id END) AS not_completed
FROM exp_assignment a
LEFT JOIN game_actions b
  ON a.user_id = b.user_id
  AND b.action = 'onboarding complete'
WHERE a.exp_name = 'Onboarding'
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    a.variant,
    COUNT(a.user_id) AS total,
    COUNT(b.user_id) AS completed,
    COUNT(b.user_id) / COUNT(a.user_id) :: DECIMAL AS pct_completed
FROM exp_assignment a
LEFT JOIN game_actions b
  ON a.user_id = b.user_id
  AND b.action = 'onboarding complete'
WHERE a.exp_name = 'Onboarding'
GROUP BY 1

------------------------------------------------------- t-Test for Continous Outcomes --------------------------------------------------------------------

-- continous metrics like: amount spent, time spent on page, days an app is used, checkout flow etc.
-- goal is to figure out if the average values in a statistically significant way
-- two way t-test to determine whether we can reject the null hypothesis that theres nothing going on 

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    a.variant,
    a.user_id,
    COALESCE(b.amount,0) AS amount
FROM exp_assignment a
LEFT JOIN game_purchases b
  ON a.user_id = b.user_id
WHERE a.exp_name = 'Onboarding'

----------------------------------------------------------------------------------------------------------------------------------------------------------
  
-- the previous query did not return a unique record for every user_id, so this groups the amount spent on user_id
  
SELECT
    a.variant,
    a.user_id,
    SUM(COALESCE(b.amount,0)) AS amount
FROM exp_assignment a
LEFT JOIN game_purchases b
  ON a.user_id = b.user_id
WHERE a.exp_name = 'Onboarding'    
GROUP BY 1,2
        
----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    variant,
    COUNT(user_id) AS total_cohorted,
    AVG(amount) AS mean_amount,
    STDDEV(amount) AS stddev_amount
FROM
        (SELECT
            a.variant,
            a.user_id,
            SUM(COALESCE(b.amount,0)) AS amount
        FROM exp_assignment a
        LEFT JOIN game_purchases b
          ON a.user_id = b.user_id
        WHERE a.exp_name = 'Onboarding'    
        GROUP BY 1,2) aa
GROUP BY 1
        
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- an additional inner join to game_actions to get back only the users who completed onboarding

SELECT
    variant,
    COUNT(user_id) AS total_cohorted,
    AVG(aa.amount) AS mean_amount,
    STDDEV(amount) AS stddev_amount
FROM
        (SELECT
            a.variant,
            a.user_id,
            SUM(COALESCE(b.amount,0)) AS amount
        FROM exp_assignment a
        LEFT JOIN game_purchases b
          ON a.user_id = b.user_id
        JOIN game_actions c
          ON a.user_id = c.user_id
         AND c.action = 'onboarding complete'
        WHERE a.exp_name = 'Onboarding'    
        GROUP BY 1,2) aa
GROUP BY 1

------------------------------- Challenges with Experiments and Options for Rescuing Flawed Experiments --------------------------------------------------

-- if an entire premise of an experiment is flawed, sql can't do much saving

---- Variant Assignment ----------------------------------------------------------------------------------------------------------------------------------

-- errors in the assignment process due to: technical failure, flawed specifications, software limitations
-- result can be unequal sized cohorts or entities not randomly assigned
-- if too many entities were cohorted, sql can narrow down to the entities who should have been selected
-- ex. if cohort groups should have only applied to new users but were assigned to everyone
-- we can use sql to restrict the entities in the cohorts to those who registered lately etc.
-- is the sample size large enough to produce statistically significant results? if not get the right sample size
-- consider all the possible bias that could be introduced into how entities are assigned groups 
-- not properly random assignment invalidates the whole experiment 
-- careful data profiling beforehand 
-- A/A testing can help uncover flaws, both cohorts recieve the control treatment and you shouldn't see stat sign results

---- Outliers --------------------------------------------------------------------------------------------------------------------------------------------

-- continuous metrics are sensitive to extreme values
-- since we rely on average aggregations these values could have impact on results
-- one user who happens to make a shit load of purchases assigned to either group has a major impact on the group they're assigned to affecting average
-- possible solutions
        -- remove the outlier values and replace with winsorized values
        -- convert the success metric into a binary outcome
        -- ex. rather than comparing average total purchase amounts per customer, we look at if they made a purchase and look at purchase rate
        -- set success metric to a threshold, what that threshold specifically is can depend on whats meaningful to the organization

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    a.variant,
    COUNT(DISTINCT a.user_id) AS total_cohort,
    COUNT(DISTINCT b.user_id) AS purchasers,
    COUNT(DISTINCT b.user_id) / COUNT(DISTINCT a.user_id) :: DECIMAL AS pct_purchased
FROM exp_assignment a
LEFT JOIN game_purchases b 
  ON a.user_id = b.user_id
JOIN game_actions c
  ON a.user_id = c.user_id
  AND c.action = 'onboarding complete'
WHERE a.exp_name = 'Onboarding'
GROUP BY 1

---- Time Boxing -----------------------------------------------------------------------------------------------------------------------------------------

-- time boxing imposes a fixed length of time relative to the experiment entry data and only considers actions during that window
-- approapriate time box size depends on the metric you are measuring
-- ex. measuring actions that typically have an immediate response -> 1 hour time box
-- ex. measuring purchase convertions -> 1-7 days time box
-- create time box size based on how long a typical action takes users
-- if a typical user takes 20 days to take action, make the time box 30 days
-- all members of the cohorts need to be allowed full time to complete the action

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- same query as earlier but we've only inclused purchases within 7 days of the cohorting event
-- by left joining game_purchases, you'll still get all the records from exp_assignment, and all the records that don't match the interval date will be null 

SELECT
    variant,
    COUNT(user_id) AS total_cohorted,
    AVG(amount) AS mean_amount,
    STDDEV(amount) AS stddev_amount
FROM
        (SELECT
            a.variant,
            a.user_id,
            SUM(COALESCE(b.amount,0)) AS amount
        FROM exp_assignment a
        LEFT JOIN game_purchases b
          ON a.user_id = b.user_id
          AND b.purch_date <= a.exp_date + INTERVAL '7 days'
        WHERE a.exp_name = 'Onboarding' 
        GROUP BY 1,2) aa
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT a.*, b.*
FROM exp_assignment a
         LEFT JOIN game_purchases b
          ON a.user_id = b.user_id
          AND b.purch_date <= a.exp_date + INTERVAL '7 days' 
          
----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT a.*, b.*
FROM exp_assignment a
        LEFT JOIN game_purchases b
          ON a.user_id = b.user_id
WHERE b.purch_date <= a.exp_date + INTERVAL '7 days' 

---- Repeated exposure experiments -----------------------------------------------------------------------------------------------------------------------

-- one and done vs. repeated exposure
-- one and done experiences can only happen to a user once, can't repeat the process, analyzing this is relatively straightforward
-- repeated exposure experiences are where a user encounters multiple changes over the course of their time using a product or service
-- difficulties around repeated exposure come from the novelty effect -> tendency for behavior to change just because something is new, not because its better/worse
-- when a change happens the initial metrics look good but that may be due to novelty effect
-- to combat this, we look at regression to the mean tendency and allow passage of time long enough for this regression to happen
-- perform cohort analysis where entities can be observed for longer periods of time 

------------------------------------------ Alternatives When Controlled Experiments Aren't Possible-------------------------------------------------------

-- reasons why controlled experiments might not be possible: ethical, practical, regulatory boundaries
-- also when a change happened in the past and the data has already been collected
-- perhaps we want to analyze a change that wasn't intended to ever happen
-- quasi-experimental methods: constructing distinct groups from the data that represent control and treatment groups

---- Pre/Post Analysis -----------------------------------------------------------------------------------------------------------------------------------

-- this analysis compares the same (or similar) populations before and after a specific change
-- before acts as the control and after is treatment group
-- needs a clearly defined change happening on a specific date, groups should be cleanly divided, and periods should be equal
-- important to keep in mind that other factors may be influencing the results outside of the change you are examining
-- this type of analysis is not as good as true randomized experiments at proving causality

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- single case statement to assign users to the two variants and group by those variants
-- we're restricting to just records that contain the email optin  

SELECT
    CASE WHEN a.created BETWEEN '2020-01-13' AND '2020-01-26' THEN 'pre'
         WHEN a.created BETWEEN '2020-01-27' AND '2020-02-09' THEN 'post' END AS variant,
    COUNT(DISTINCT a.user_id) AS cohorted,
    COUNT(DISTINCT b.user_id) AS opted_in,
    COUNT(DISTINCT b.user_id) / COUNT(DISTINCT a.user_id) :: DECIMAL AS pct_opted_in,
    COUNT(DISTINCT a.created) AS days
FROM game_users a
        LEFT JOIN game_actions b
          ON a.user_id = b.user_id
          AND b.action = 'email_optin'
WHERE a.created BETWEEN '2020-01-13' AND '2020-02-09'
GROUP BY 1

---- Natural Experiment Analysis -------------------------------------------------------------------------------------------------------------------------

-- when entities end up with different experiences though some process that approximates randomness 
-- unintentional groupings into experimental and control groups
-- there must be a clear distinction between those that recieved treatment and those that didn't
-- finding a comparable population to compare your unintentional treament group to may be difficult
-- you have to be very careful about controlling for confounding variables
-- but since its not really an experiment you can't rule out confounding variables influencing the measured differences
-- again this is not true random assignment, and the evidence for causality is weaker

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    a.country,
    COUNT(DISTINCT a.user_id) AS total_cohort,
    COUNT(DISTINCT b.user_id) AS purchases,
    ROUND(COUNT(DISTINCT b.user_id) / COUNT(DISTINCT a.user_id) :: DECIMAL,4) AS pct_purchased
FROM game_users a
LEFT JOIN game_purchases b
  ON a.user_id = b.user_id
WHERE a.country IN ('United States','Canada')
GROUP BY 1

---- Analysis of Populations Around a Threshold ----------------------------------------------------------------------------------------------------------


-- the response value you get from your subject may be a continuous value with a threshold on either sides
-- instead of looking at the entire population, we can compare just the subjects that fall in the high threshold range to subjects in the low threshold range 
-- we can construct our variants by splitting the data around these thresholds
-- regression discontinuity design (RDD) is the formal name for this method
-- the variants should be of similar size and be large enough to be able to determine statistical significance if its there
-- best use of this method involves picking a few different threshold ranges (top/bottom 5%, top/bottom 10% etc.)
-- again, this can prove causality but less conclusively
-- pay careful attention to possible confounding factors that make your results less reliable