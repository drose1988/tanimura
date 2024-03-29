----------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------- COHORT ANALYSIS ------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- breaking populations down into cohorts and following them over is a powerful way to analyze your data and avoid biases
-- cohort analysis shows how subpopulations differ and how they change over time 
-- retention, survivorship, returnship, cumulative
-- combining cohort analysis with cross-sectional analysis

------------------------------------------------ Cohorts: A Useful Analysis Framework --------------------------------------------------------------------

-- a cohort is a group of people who share characteristic of interest at the time we start observing them
-- any type of entity we want to study
-- comparing these entities over time
-- detecting correlations between the cohort characterstics
-- can lead to hypotheses about causal drivers
-- monitoring new cohorts and compare to previous cohorts
-- 3 components of cohort analysis: cohort grouping, time series, and aggregate metric
-- cohort grouping often based on a start date, important to cohort only on the value of the start date
-- cohort vs. segment
    --cohorting follows entities who have a common start date and are followed over a time frame, segments of users are be any point in time
-- time series element should cover the entire life of the entities
-- survivorship bias will occur when you don't follow entities life span
-- time series should be long enough for the entities to complete the actions of interest
-- time series is usually measured in number of periods elapsed from the start date
-- the interval between periods can be year, month, day etc.
-- cohort aggregate metrics are usually sum,count,average

------------------------------------------------ Retention, Survivorship, Returnship, Cumulative ---------------------------------------------------------

-- retention: whether the cohort member has a record in the time series on a particular date, expressed in number of periods from start date
-- survivorship: how many entities remained in the data set for a certain length of time, regardless of frequency of actions in that time
-- returnship: whether an action has happened more than a minimum threshold of times, like more than once over a specific window of time
-- cumulative: calculations the total number or amount measured at one or more fixed time windows, regardless of when they happened

------------------------------------------------ Retention -----------------------------------------------------------------------------------------------

-- to retain means to keep
-- retaining customers is more profitable than acquiring new ones
-- main question of retention analysis is whether the starting size of the cohort will remain constant, decay, or increase over time
-- when there's an increase or decrease, at what speed are they moving
-- starting size will decay over time
-- count of entities at each perdod from the starting date divided by count of entities from the starting point
-- displayed in table or graph form known as the retention curve
-- often a steep drop initially, important to pay attention to the curve in inital periods
-- does the curve flatten after inital drop or continue to continue to decay rapidly or inflect upwards
-- look for an increase in revenue per customer over time

------------------------------------------------ SQL for Basic Revention Curve ---------------------------------------------------------------------------

-- time series will be terms in office for legislators
-- metric of interest is the count of legislators still in office in each period from the starting date
-- create first_term for each legislator

SELECT 
    DISTINCT a.id_bioguide,
    DATE_PART('year',age(b.term_start,a.first_term)) as period
FROM
(SELECT id_bioguide, MIN(term_start) AS first_term
FROM legislators_terms
GROUP BY 1) a
JOIN legislators_terms b
ON a.id_bioguide = b.id_bioguide

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- period column tells us how many years from a legislators first start date to the start date of a particular term 
-- you'll get multiple records of the same id_bioguide if they were elected more than once
-- so count aggregate on the id_bioguide to get number of legislators elected that lasted x amount of periods

SELECT 
    date_part('year',AGE(b.term_start,a.first_term)) AS period,
    COUNT(DISTINCT a.id_bioguide) AS cohort_retained
FROM
    (SELECT id_bioguide, MIN(term_start) AS first_term
    FROM legislators_terms
    GROUP BY 1) a
JOIN legislators_terms b
ON a.id_bioguide = b.id_bioguide
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- we need to create a column for total cohort size that keeps same inital value of all the records
-- window function to get the first record of cohort_retained not partitioned just ordered by period

SELECT
    period,
    FIRST_VALUE(cohort_retained) OVER (ORDER BY period) as cohort_size,
    cohort_retained,
    cohort_retained / FIRST_VALUE(cohort_retained) OVER (ORDER BY period) :: DECIMAL as pct_retained
FROM
        (SELECT 
            date_part('year',AGE(b.term_start,a.first_term)) AS period,
            COUNT(DISTINCT a.id_bioguide) AS cohort_retained
        FROM
            (SELECT id_bioguide, MIN(term_start) AS first_term
            FROM legislators_terms
            GROUP BY 1) a
        JOIN legislators_terms b
        ON a.id_bioguide = b.id_bioguide
        GROUP BY 1) aa
        
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- reshape the data to show it in table format
-- the problem with this output is that legislators are elected every 2 or 6 years
-- so we are missing the data where the legislator was still in office but not reelected after 1 year
-- for a time series analysis, the data needs to accurately reflect the presence or absence of entities over each time period
-- in this case they don't because period 1 shows 28% dropoff that is not actually the case because legislators weren't running for reelection

SELECT
    cohort_size,
    MAX(CASE WHEN period = 0 THEN pct_retained ELSE NULL END) AS yr0,
    MIN(CASE WHEN period = 1 THEN pct_retained ELSE NULL END) AS yr1,
    MAX(CASE WHEN period = 2 THEN pct_retained ELSE NULL END) AS yr2,
    MIN(CASE WHEN period = 3 THEN pct_retained ELSE NULL END) AS yr3,
    MAX(CASE WHEN period = 4 THEN pct_retained ELSE NULL END) AS yr4
FROM   
        (SELECT
            period,
            FIRST_VALUE(cohort_retained) OVER (ORDER BY period) as cohort_size,
            cohort_retained,
            ROUND(cohort_retained / FIRST_VALUE(cohort_retained) OVER (ORDER BY period) :: DECIMAL,4) as pct_retained
        FROM
                (SELECT 
                    date_part('year',AGE(b.term_start,a.first_term)) AS period,
                    COUNT(DISTINCT a.id_bioguide) AS cohort_retained
                FROM
                    (SELECT id_bioguide, MIN(term_start) AS first_term
                    FROM legislators_terms
                    GROUP BY 1) a
                JOIN legislators_terms b
                ON a.id_bioguide = b.id_bioguide
                GROUP BY 1) aa) aaa
GROUP BY 1

------------------------------------------------ Adjusting Time Series to Increate Retention Accuracy ----------------------------------------------------

-- for a time series analysis, the data needs to accurately reflect the presence or absence of entities over each time period
-- an entity can persist in the data but we might not always capture it
-- we need a way to derive the span of time in which the entity is still present
-- we need to fill in the missing values for years that legislators were still in office between new terms
-- so we create a data set that contains a record for each december 31st that each legislator is in office
-- this is similar to a previous query but we've added a date field

SELECT
    a.id_bioguide,
    a.first_term,
    b.term_start,
    b.term_end,
    c.date,
    COALESCE(DATE_PART('year', AGE(c.date, a.first_term)),0) AS period
FROM
       (SELECT id_bioguide, MIN(term_start) AS first_term
        FROM legislators_terms
        GROUP BY 1) a
JOIN legislators_terms b 
    ON a.id_bioguide = b.id_bioguide
LEFT JOIN date_dim c 
    ON c.date BETWEEN b.term_start AND b.term_end
    AND c.month_name = 'December' AND c.day_of_month = 31
    
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- we use the coalesce function here for cases when a legislator's term starts and ends in the same year
-- by assigning it 0 we're crediting it as a year served
-- this output represents the legislators retained through each period
-- we join table b so just so we can specify our dates from table c according to our time range

SELECT
    COALESCE(date_part('year', AGE(c.date, a.first_term)),0) AS period,
    COUNT(DISTINCT a.id_bioguide) AS cohort_retained
FROM
        (SELECT id_bioguide, MIN(term_start) AS first_term
         FROM legislators_terms
         GROUP BY 1) a
JOIN legislators_terms b 
  ON a.id_bioguide = b.id_bioguide
LEFT JOIN date_dim c 
  ON c.date BETWEEN b.term_start AND b.term_end
  AND c.month_name = 'December' AND c.day_of_month = 31
GROUP BY 1
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- to get cohort_size and pct_retained its easy to wrap everything in a subquery
-- then you can use your window funtion and math operation with period and cohort_retained

SELECT 
    period,
    FIRST_VALUE(cohort_retained) OVER (ORDER BY period) AS cohort_size,
    cohort_retained,
    ROUND(cohort_retained / FIRST_VALUE(cohort_retained) OVER (ORDER BY period) :: DECIMAL,3) AS pct_retained
FROM        
        (SELECT
            COALESCE(date_part('year', AGE(c.date, a.first_term)),0) AS period,
            COUNT(DISTINCT a.id_bioguide) AS cohort_retained
        FROM
               (SELECT id_bioguide, MIN(term_start) AS first_term
                FROM legislators_terms
                GROUP BY 1) a
        JOIN legislators_terms b 
            ON a.id_bioguide = b.id_bioguide
        LEFT JOIN date_dim c 
            ON c.date BETWEEN b.term_start AND b.term_end
            AND c.month_name = 'December' AND c.day_of_month = 31
        GROUP BY 1) aa
        
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- this method doesn't capture instances in which a legislator did not complete a full term
-- this method is used to impute an end date, works if we know exactly how long the term is

SELECT
    a.id_bioguide,
    a.first_term,
    b.term_start,
    CASE WHEN b.term_type = 'rep' THEN CAST(b.term_start + INTERVAL '2 years' AS DATE)
         WHEN b.term_type = 'sen' THEN CAST(b.term_start + INTERVAL '6 years' AS DATE)
         END AS term_end
FROM
        (SELECT
            id_bioguide,
            MIN(term_start) as first_term
        FROM legislators_terms
        GROUP BY 1) a
JOIN legislators_terms b
ON a.id_bioguide = b.id_bioguide
ORDER BY 1,2

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- subsequent start date method
-- this window function is saying 'get next record of term_start of the same id_bioguide, next record will be according to the order of term_start
-- legislators that serve one term will not have a next record
-- this assumes all terms are consecutive with no time spent out of office
-- we shouldn't fill in gaps with assumptions

SELECT
    a.id_bioguide,
    a.first_term,
    b.term_start,
    CAST(LEAD(b.term_start) OVER(PARTITION BY a.id_bioguide ORDER BY b.term_start) - INTERVAL '1 day' AS DATE) AS term_end
FROM
        (SELECT
            id_bioguide,
            MIN(term_start) as first_term
        FROM legislators_terms
        GROUP BY 1) a
JOIN legislators_terms b
    ON a.id_bioguide = b.id_bioguide
ORDER BY 1,2
------------------------------------------------ Cohorts Derived from the Time Series Itself -------------------------------------------------------------

-- how to derive your cohort groupings from the time series itself
-- most common way to create cohorts is based on the first time the entity appears in the time series
-- time based cohorts can be grouped by any time granularity that is meaningful to the organization
-- the question we're asking is whether the era in which the legislator took office has any correlation with their retention

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- this tells us what the first year they took office
-- the period field can be viewed like this: since we narrowed down c.date to include all the 12/31 days between the term_start and term_end
-- even though our first subquery table has been aggregated down so id_bioguide is flattened
-- when we join a date_dim table its gonna populate the output with more records of each legislator if they had a 12/31 day somewhere in their term

SELECT
    -- a.id_bioguide,
    -- DATE_PART('year',a.first_term) AS first_year,
    COALESCE(DATE_PART('year', AGE(c.date,a.first_term)),0) AS period,
    a.*,
    c.date
FROM 
        (SELECT
            id_bioguide,
            MIN(term_start) AS first_term
        FROM legislators_terms
        GROUP BY 1) a
JOIN legislators_terms b
    ON a.id_bioguide = b.id_bioguide
LEFT JOIN date_dim c
    ON c.date BETWEEN b.term_start AND b.term_end
    AND c.month_name = 'December' AND c.day_of_month = 31
ORDER BY 2,4

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- then use a count of legislators grouped by their first_year and period
-- this output says "89 legislators had their first year in 1789, of those that started in 1789 16 were still retained in the 10th period"

SELECT
    DATE_PART('year',a.first_term) AS first_year,
    COALESCE(DATE_PART('year', AGE(c.date,a.first_term)),0) AS period,
    COUNT(DISTINCT a.id_bioguide) AS cohort_retained
FROM 
        (SELECT
            id_bioguide,
            MIN(term_start) AS first_term
        FROM legislators_terms
        GROUP BY 1) a
JOIN legislators_terms b
    ON a.id_bioguide = b.id_bioguide
LEFT JOIN date_dim c
    ON c.date BETWEEN b.term_start AND b.term_end
    AND c.month_name = 'December' AND c.day_of_month = 31
GROUP BY 1,2

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- method used to calcuate years cohorts
-- for the cohort_size column, we take the first value of our cohort_retained grouped by each first_year value
-- ordering by period is needed for the function to know what the first value actually is

SELECT
    first_year,
    period,
    FIRST_VALUE(cohort_retained) OVER(PARTITION BY first_year ORDER BY period) AS cohort_size,
    cohort_retained,
    ROUND(cohort_retained / FIRST_VALUE(cohort_retained) OVER(PARTITION BY first_year ORDER BY period) :: DECIMAL,3) AS pct_retained
FROM
        (SELECT
            DATE_PART('year',a.first_term) AS first_year,
            COALESCE(DATE_PART('year', AGE(c.date,a.first_term)),0) AS period,
            COUNT(DISTINCT a.id_bioguide) AS cohort_retained
        FROM 
                (SELECT
                    id_bioguide,
                    MIN(term_start) AS first_term
                FROM legislators_terms
                GROUP BY 1) a
        JOIN legislators_terms b
            ON a.id_bioguide = b.id_bioguide
        LEFT JOIN date_dim c
            ON c.date BETWEEN b.term_start AND b.term_end
            AND c.month_name = 'December' AND c.day_of_month = 31
        GROUP BY 1,2) aa
        
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- now we're changing our time series from year to century
-- we're specifying the century that the legislator started in first_term and their assigned that value throughout
-- "there were 368 legislators that started holding office in the 18th century, in the 10th period(still years) 70 of those 368 legislators held office"

SELECT
    first_century,
    period,
    FIRST_VALUE(cohort_retained) OVER(PARTITION BY first_century ORDER BY period) AS cohort_size,
    cohort_retained,
    ROUND(cohort_retained / FIRST_VALUE(cohort_retained) OVER(PARTITION BY first_century ORDER BY period) :: DECIMAL,3) AS pct_retained
FROM
        (SELECT
            DATE_PART('century',a.first_term) AS first_century,
            COALESCE(DATE_PART('year', AGE(c.date,a.first_term)),0) AS period,
            COUNT(DISTINCT a.id_bioguide) AS cohort_retained
        FROM 
                (SELECT
                    id_bioguide,
                    MIN(term_start) AS first_term
                FROM legislators_terms
                GROUP BY 1) a
        JOIN legislators_terms b
            ON a.id_bioguide = b.id_bioguide
        LEFT JOIN date_dim c
            ON c.date BETWEEN b.term_start AND b.term_end
            AND c.month_name = 'December' AND c.day_of_month = 31
        GROUP BY 1,2) aa
ORDER BY 1,2
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- for doing analysis according legislator's state we want to use the first state they held office in and the first term date
-- that way we avoid inconsistencies, like a legislator showing up in both state groupings
-- its important to ensure that each entity is assigned only one value, otherwise they may appear in multiple cohorts

SELECT
    DISTINCT id_bioguide,
    MIN(term_start) OVER(PARTITION BY id_bioguide) AS first_term,
    FIRST_VALUE(state) OVER(PARTITION BY id_bioguide ORDER BY term_start) AS first_state
FROM legislators_terms
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- we do the same date_dim join with narrowed down dates
-- this tells us the total number of legislators per state who's first time holding office was in that state
-- and how the retention rate has decayed through each period

SELECT
    a.first_state,
    COALESCE(DATE_PART('year', AGE(c.date,a.first_term)),0) AS period,
    COUNT(DISTINCT a.id_bioguide) AS cohort_retained
    FROM 
        (SELECT
            DISTINCT id_bioguide,
            MIN(term_start) OVER(PARTITION BY id_bioguide) AS first_term,
            FIRST_VALUE(state) OVER(PARTITION BY id_bioguide ORDER BY term_start) AS first_state
         FROM legislators_terms) a
JOIN legislators_terms b
            ON a.id_bioguide = b.id_bioguide
LEFT JOIN date_dim c
    ON c.date BETWEEN b.term_start AND b.term_end
    AND c.month_name = 'December' AND c.day_of_month = 31
GROUP BY 1,2
----------------------------------------------------------------------------------------------------------------------------------------------------------
-- from there a window function does this "take the first value of cohort_retained for each first_state ordered by the period field"
-- that cohort_size represents the starting amount of the cohort for each state
-- then we can compare that total to the cohort_retained for each period and its percent of the total

SELECT
    first_state,
    period,
    FIRST_VALUE(cohort_retained) OVER(PARTITION BY first_state ORDER BY period) AS cohort_size,
    cohort_retained,
    ROUND(cohort_retained / FIRST_VALUE(cohort_retained) OVER(PARTITION BY first_state ORDER BY period) :: DECIMAL,4) AS pct_retained
FROM
        (SELECT
            a.first_state,
            COALESCE(DATE_PART('year', AGE(c.date,a.first_term)),0) AS period,
            COUNT(DISTINCT a.id_bioguide) AS cohort_retained
            FROM 
                (SELECT
                    DISTINCT id_bioguide,
                    MIN(term_start) OVER(PARTITION BY id_bioguide) AS first_term,
                    FIRST_VALUE(state) OVER(PARTITION BY id_bioguide ORDER BY term_start) AS first_state
                 FROM legislators_terms) a
        JOIN legislators_terms b
                    ON a.id_bioguide = b.id_bioguide
        LEFT JOIN date_dim c
            ON c.date BETWEEN b.term_start AND b.term_end
            AND c.month_name = 'December' AND c.day_of_month = 31
        GROUP BY 1,2) aa
        
------------------------------------------------ Defining the Cohort from a Seperate Table ---------------------------------------------------------------

-- often characteristics that define a cohort can exist in another table
-- in this case gender is the attribute we need to grab from the legislators table
-- in the first subquery we're getting distinct legislators and the first term start time, along with the first state they were first elected in
-- this is straightforward when we window function to group by the id_bioguide
-- we need date_dim table to create our period field 
-- and in order to narrow down the dates we pull legislators_terms to only get dates between start term and end term

        SELECT
            d.gender,
            COALESCE(DATE_PART('year', AGE(c.date,a.first_term)),0) AS period,
            COUNT(DISTINCT a.id_bioguide) AS cohort_retained
            FROM 
                (SELECT
                    DISTINCT id_bioguide,
                    MIN(term_start) OVER(PARTITION BY id_bioguide) AS first_term,
                    FIRST_VALUE(state) OVER(PARTITION BY id_bioguide ORDER BY term_start) AS first_state
                 FROM legislators_terms) a
        JOIN legislators_terms b
                    ON a.id_bioguide = b.id_bioguide
        LEFT JOIN date_dim c
            ON c.date BETWEEN b.term_start AND b.term_end
            AND c.month_name = 'December' AND c.day_of_month = 31
        JOIN legislators d
            ON a.id_bioguide = d.id_bioguide
        GROUP BY 1,2
        ORDER BY 2
        
----------------------------------------------------------------------------------------------------------------------------------------------------------
-- just like with state, we're using a window function to group our first cohort_retained value by gender

SELECT
    gender,
    period,
    FIRST_VALUE(cohort_retained) OVER (PARTITION BY gender ORDER BY period) AS cohort_size,
    cohort_retained,
    ROUND(cohort_retained / FIRST_VALUE(cohort_retained) OVER (PARTITION BY gender ORDER BY period)::DECIMAL,4) AS pct_retained
FROM        
        (SELECT
            d.gender,
            COALESCE(DATE_PART('year', AGE(c.date,a.first_term)),0) AS period,
            COUNT(DISTINCT a.id_bioguide) AS cohort_retained
        FROM 
                (SELECT
                    DISTINCT id_bioguide,
                    MIN(term_start) OVER(PARTITION BY id_bioguide) AS first_term,
                    FIRST_VALUE(state) OVER(PARTITION BY id_bioguide ORDER BY term_start) AS first_state
                 FROM legislators_terms) a
        JOIN legislators_terms b
            ON a.id_bioguide = b.id_bioguide
        LEFT JOIN date_dim c
            ON c.date BETWEEN b.term_start AND b.term_end
            AND c.month_name = 'December' AND c.day_of_month = 31
        JOIN legislators d
            ON a.id_bioguide = d.id_bioguide
        GROUP BY 1,2) aa
ORDER BY 2,1
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- same query but here we've narrowed down to where the first term is not before 1917 and not after 1999
-- this demonstrates the importance of setting up appropriate cohorts and ensuing that they have comparable mounts of time
-- if cohort analysis is about comparing the length of time of completing an action, you need to have a fixed time frame (apples to apples comparison)

SELECT
    gender,
    period,
    FIRST_VALUE(cohort_retained) OVER (PARTITION BY gender ORDER BY period) AS cohort_size,
    cohort_retained,
    ROUND(cohort_retained / FIRST_VALUE(cohort_retained) OVER (PARTITION BY gender ORDER BY period)::DECIMAL,4) AS pct_retained
FROM        
        (SELECT
            d.gender,
            COALESCE(DATE_PART('year', AGE(c.date,a.first_term)),0) AS period,
            COUNT(DISTINCT a.id_bioguide) AS cohort_retained
        FROM 
                (SELECT
                    DISTINCT id_bioguide,
                    MIN(term_start) OVER(PARTITION BY id_bioguide) AS first_term,
                    FIRST_VALUE(state) OVER(PARTITION BY id_bioguide ORDER BY term_start) AS first_state
                 FROM legislators_terms) a
        JOIN legislators_terms b
            ON a.id_bioguide = b.id_bioguide
        LEFT JOIN date_dim c
            ON c.date BETWEEN b.term_start AND b.term_end
            AND c.month_name = 'December' AND c.day_of_month = 31
        JOIN legislators d
            ON a.id_bioguide = d.id_bioguide
        WHERE a.first_term BETWEEN '1917-01-01' AND '1999-12-31'
        GROUP BY 1,2) aa
ORDER BY 2,1

---------------------------------------------- Dealing with Sparse Cohorts -------------------------------------------------------------------------------

-- when you divide the population into cohorts based on multiple criteria, it can lead to sparce cohorts
-- meaning some of the defined groups are too small and not represented in the data set for the whole time
-- if the cohort is too small the results, they may be represented sporatically in the data
-- if they disappear from the results set, they can appear as zero retention value

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- for example in this query, we're trying to get retention for cohort groups based on gender and state
-- there are only 3 alabama female legislators starting in our cohort and none last past the first period

SELECT
    first_state,
    gender,
    period,
    FIRST_VALUE(cohort_retained) OVER (PARTITION BY first_state,gender ORDER BY period) AS cohort_size,
    cohort_retained,
    ROUND(cohort_retained / FIRST_VALUE(cohort_retained) OVER (PARTITION BY first_state,gender ORDER BY period)::DECIMAL,4) AS pct_retained
FROM        
        (SELECT
            a.first_state,
            d.gender,
            COALESCE(DATE_PART('year', AGE(c.date,a.first_term)),0) AS period,
            COUNT(DISTINCT a.id_bioguide) AS cohort_retained
        FROM 
                (SELECT
                    DISTINCT id_bioguide,
                    MIN(term_start) OVER(PARTITION BY id_bioguide) AS first_term,
                    FIRST_VALUE(state) OVER(PARTITION BY id_bioguide ORDER BY term_start) AS first_state
                 FROM legislators_terms) a
        JOIN legislators_terms b
            ON a.id_bioguide = b.id_bioguide
        LEFT JOIN date_dim c
            ON c.date BETWEEN b.term_start AND b.term_end
            AND c.month_name = 'December' AND c.day_of_month = 31
        JOIN legislators d
            ON a.id_bioguide = d.id_bioguide
        WHERE a.first_term BETWEEN '1917-01-01' AND '1999-12-31'
        GROUP BY 1,2,3) aa
ORDER BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- subquery aa returns the starting size of our cohort groups 
-- joining aa to the generate series table gives us a fixed column of values 0-20 for each gender of each state
-- this way we can create a time series of 20 years that applies to all gender/state combinations even for a gender/state that doesn't last 20 years 
-- along with the fixed starting cohort size

SELECT
    aa.gender,
    aa.first_state AS state,
    cc.period,
    aa.cohort_size AS cohort
FROM
        (SELECT
            b.gender,
            a.first_state,
            COUNT(a.id_bioguide) AS cohort_size
        FROM 
                (SELECT
                    DISTINCT id_bioguide,
                    MIN(term_start) OVER (PARTITION BY id_bioguide) AS first_term,
                    FIRST_VALUE(state) OVER (PARTITION BY id_bioguide ORDER BY term_start) AS first_state
                FROM legislators_terms) a
        JOIN legislators b
            ON a.id_bioguide = b.id_bioguide
        WHERE a.first_term BETWEEN '1917-01-01' AND '1999-12-31'
        GROUP BY 1,2) aa
JOIN
        (SELECT generate_series AS period
         FROM generate_series(0,20,1)) cc
ON 1 = 1
ORDER BY 1,2,3

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- we take the previous query and call it aaa
-- we left join an older query that had the actual cohort_retained periods of each gender/state
-- when we select period we only get 0-20 periods and exclude the remaining cohort retention for a gender/state
-- we use coalesce for the times a gender/state doesn't make it to 20 periods but we want the zero value returned
-- if we were to inner join aaa and bbb, our period would only last the length that a gender/state had a value in cohort_retained

SELECT
    aaa.gender,
    aaa.first_state,
    aaa.period,
    aaa.cohort_size,
    COALESCE(ddd.cohort_retained,0) AS cohort_retained,
    ROUND(COALESCE(ddd.cohort_retained,0) / aaa.cohort_size :: DECIMAL,3) AS pct_retained
FROM
        (SELECT
                aa.gender,
                aa.first_state,
                cc.period,
                aa.cohort_size
        FROM
            (SELECT
                b.gender,
                a.first_state,
                COUNT(a.id_bioguide) AS cohort_size
             FROM 
                (SELECT
                    DISTINCT id_bioguide,
                    MIN(term_start) OVER (PARTITION BY id_bioguide) AS first_term,
                    FIRST_VALUE(state) OVER (PARTITION BY id_bioguide ORDER BY term_start) AS first_state
                FROM legislators_terms) a
             JOIN legislators b
                        ON a.id_bioguide = b.id_bioguide
             WHERE a.first_term BETWEEN '1917-01-01' AND '1999-12-31'
             GROUP BY 1,2) aa
        JOIN
            (SELECT generate_series AS period
             FROM generate_series(0,20,1)) cc
        ON 1 = 1
        ORDER BY 1,2,3) aaa
LEFT JOIN
        (SELECT 
            d.first_state,
            g.gender,
            COALESCE(DATE_PART('year',AGE(f.date, d.first_term)),0) AS period,
            COUNT(DISTINCT d.id_bioguide) AS cohort_retained
        FROM
            (SELECT 
                DISTINCT id_bioguide,
                MIN(term_start) OVER(PARTITION BY id_bioguide) AS first_term,
                FIRST_VALUE(state) OVER(PARTITION BY id_bioguide ORDER BY term_start) AS first_state
             FROM legislators_terms) d
        JOIN legislators_terms e ON d.id_bioguide = e.id_bioguide
        LEFT JOIN date_dim f ON f.date BETWEEN e.term_start AND e.term_end
            AND f.month_name = 'December' AND f.day_of_month = 31
        JOIN legislators g ON d.id_bioguide = g.id_bioguide
        WHERE d.first_term BETWEEN '1917-01-01' AND '1999-12-31'
        GROUP BY 1,2,3) ddd
ON aaa.first_state = ddd.first_state AND aaa.gender = ddd.gender AND aaa.period = ddd.period
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- this takes the longer data set from the previous query and pivots it into a more compact form

SELECT
    gender,
    first_state,
    MAX(CASE WHEN period = 0 THEN pct_retained END) AS yr0,
    MAX(CASE WHEN period = 2 THEN pct_retained END) AS yr2,
    MAX(CASE WHEN period = 4 THEN pct_retained END) AS yr4,
    MAX(CASE WHEN period = 6 THEN pct_retained END) AS yr6,
    MAX(CASE WHEN period = 8 THEN pct_retained END) AS yr8,
    MAX(CASE WHEN period = 10 THEN pct_retained END) AS yr10,
    MAX(CASE WHEN period = 12 THEN pct_retained END) AS yr12
FROM
        (SELECT
            aaa.gender,
            aaa.first_state,
            aaa.period,
            aaa.cohort_size,
            COALESCE(ddd.cohort_retained,0) AS cohort_retained,
            ROUND(COALESCE(ddd.cohort_retained,0) / aaa.cohort_size :: DECIMAL,3) AS pct_retained
        FROM
                (SELECT
                        aa.gender,
                        aa.first_state,
                        cc.period,
                        aa.cohort_size
                FROM
                    (SELECT
                        b.gender,
                        a.first_state,
                        COUNT(a.id_bioguide) AS cohort_size
                     FROM 
                        (SELECT
                            DISTINCT id_bioguide,
                            MIN(term_start) OVER (PARTITION BY id_bioguide) AS first_term,
                            FIRST_VALUE(state) OVER (PARTITION BY id_bioguide ORDER BY term_start) AS first_state
                        FROM legislators_terms) a
                     JOIN legislators b
                                ON a.id_bioguide = b.id_bioguide
                     WHERE a.first_term BETWEEN '1917-01-01' AND '1999-12-31'
                     GROUP BY 1,2) aa
                JOIN
                    (SELECT generate_series AS period
                     FROM generate_series(0,20,1)) cc
                ON 1 = 1
                ORDER BY 1,2,3) aaa
        LEFT JOIN
                (SELECT 
                    d.first_state,
                    g.gender,
                    COALESCE(DATE_PART('year',AGE(f.date, d.first_term)),0) AS period,
                    COUNT(DISTINCT d.id_bioguide) AS cohort_retained
                FROM
                    (SELECT 
                        DISTINCT id_bioguide,
                        MIN(term_start) OVER(PARTITION BY id_bioguide) AS first_term,
                        FIRST_VALUE(state) OVER(PARTITION BY id_bioguide ORDER BY term_start) AS first_state
                     FROM legislators_terms) d
                JOIN legislators_terms e ON d.id_bioguide = e.id_bioguide
                LEFT JOIN date_dim f ON f.date BETWEEN e.term_start AND e.term_end
                    AND f.month_name = 'December' AND f.day_of_month = 31
                JOIN legislators g ON d.id_bioguide = g.id_bioguide
                WHERE d.first_term BETWEEN '1917-01-01' AND '1999-12-31'
                GROUP BY 1,2,3) ddd
        ON aaa.first_state = ddd.first_state AND aaa.gender = ddd.gender AND aaa.period = ddd.period) rrr
GROUP BY 1,2

------------------------------------------ Defining Cohorts from Dates Other Than The First Date ---------------------------------------------------------

-- cohorting on dates other than start time/first date can be useful 
-- important to precisely define the criteria for inclusion for each cohort
-- problems can arise when a large share of users don't show up every day
-- if you pick a day to start the time series and a user wasn't active that day they won't be included in the analysis when logically they should be
-- using a window of time is more appropriate than single day

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- here our arbitrary start time for the time series will be 2000

SELECT
    DISTINCT id_bioguide,
    term_type,
    DATE('2000-01-01') AS first_term,
    MIN(term_start) AS min_start
FROM legislators_terms
WHERE term_start <= '2000-12-31' AND term_end >= '2000-01-01'
GROUP BY 1,2,3

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- this intermediate step makes the next one less confusing 
-- it shows how we get period 
-- before we count the legislators, each record represents a time a legislator was in office 

SELECT
    a.term_type,
    a.id_bioguide,
    a.first_term,
    c.date,
    COALESCE(DATE_PART('year',AGE(c.date,a.first_term)),0) AS period
FROM
                (SELECT
                    DISTINCT id_bioguide,
                    term_type,
                    DATE('2000-01-01') AS first_term,
                    MIN(term_start) AS min_start
                 FROM legislators_terms
                 WHERE term_start <= '2000-12-31' AND term_end >= '2000-01-01'
                 GROUP BY 1,2,3) a
JOIN legislators_terms b
    ON a.id_bioguide = b.id_bioguide
    AND a.min_start <= b.term_start
LEFT JOIN date_dim c
    ON c.date BETWEEN b.term_start AND b.term_end
    AND c.month_name = 'December' AND c.day_of_month = 31 AND c.year >= 2000

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- the bigger subquery counts distinct legislators based off term_type
-- and the period is number of years between 01-01-2000 and a given 12-31-xxxx found within their time in office
-- then the outer query as usual uses the window function to get cohort_retained for each term_type and calculates the retention percentage

SELECT
    term_type,
    period,
    FIRST_VALUE(cohort_retained) OVER(PARTITION BY term_type ORDER BY period) AS cohort_size,
    cohort_retained,
    ROUND(cohort_retained / FIRST_VALUE(cohort_retained) OVER(PARTITION BY term_type ORDER BY period):: DECIMAL,4) AS pct_retained
FROM 
        (SELECT
            a.term_type,
            COALESCE(DATE_PART('year',AGE(c.date,a.first_term)),0) AS period,
            COUNT(DISTINCT a.id_bioguide) AS cohort_retained
        FROM
                (SELECT
                    DISTINCT id_bioguide,
                    term_type,
                    DATE('2000-01-01') AS first_term,
                    MIN(term_start) AS min_start
                 FROM legislators_terms
                 WHERE term_start <= '2000-12-31' AND term_end >= '2000-01-01'
                 GROUP BY 1,2,3) a
        JOIN legislators_terms b
            ON a.id_bioguide = b.id_bioguide
            AND a.min_start <= b.term_start
        LEFT JOIN date_dim c
            ON c.date BETWEEN b.term_start AND b.term_end
            AND c.month_name = 'December' AND c.day_of_month = 31 AND c.year >= 2000
        GROUP BY 1,2) aa
WHERE term_type = 'rep'
ORDER BY 2,1

--------------------------------------------- Returnship, or Repeat Purchase Behavior---------------------------------------------------------------------

-- can we expect a user to return within a given window of time (returnship) and the intensity of activity during that window (repeat purchase behavior)
-- goal is to get a complete picture of how cohorts will behave over the course of their lifespan
-- do this by making a fair comparison between your cohorts
-- use time box (fixed window of time from first date) if your cohort groups have different start dates

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- we're looking to determine how many legislators have more than one term type (specifically rep -> sen)

SELECT
    DISTINCT id_bioguide,
    MIN(term_start) AS first_term,
    MAX(term_start) AS last_term
FROM legislators_terms
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- reminder the first_term and last_term are both starting dates for a term

SELECT
    DISTINCT id_bioguide,
    DATE_PART('century',MIN(term_start)) AS first_century,
    MIN(term_start) AS first_term,
    MAX(term_start) AS last_term,
    DATE_PART('year',AGE(MAX(term_start),MIN(term_start))) AS tenure
FROM legislators_terms
GROUP BY 1
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- in the subquery we have distinct legislators
-- so we can count all the legislators
-- and count all the legislators with 10 or more terms
-- so our time box is 10 years

SELECT
    first_century AS century,
    COUNT(DISTINCT id_bioguide) AS cohort_size,
    COUNT(DISTINCT CASE WHEN tenure >= 10 THEN id_bioguide END) AS survived_10,
    ROUND(COUNT(DISTINCT CASE WHEN tenure >= 10 THEN id_bioguide END) / COUNT(DISTINCT id_bioguide) :: DECIMAL, 4) AS pct_survived_10
FROM
        (SELECT
            DISTINCT id_bioguide,
            DATE_PART('century',MIN(term_start)) AS first_century,
            MIN(term_start) AS first_term,
            MAX(term_start) AS last_term,
            DATE_PART('year',AGE(MAX(term_start),MIN(term_start))) AS tenure
        FROM legislators_terms
        GROUP BY 1) a
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    first_century,
    COUNT(DISTINCT id_bioguide) AS cohort_size,
    COUNT(DISTINCT CASE WHEN total_terms >= 5 THEN id_bioguide END) AS survived_5,
    ROUND(COUNT(DISTINCT CASE WHEN total_terms >= 5 THEN id_bioguide END) / COUNT(DISTINCT id_bioguide) :: DECIMAL, 4) AS pct_survived_5
FROM     
        (SELECT
            id_bioguide,
            DATE_PART('century',MIN(term_start)) AS first_century,
            COUNT(term_start) AS total_terms
        FROM legislators_terms
        GROUP BY 1) a
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- with this join you bring back the terms column which is just number 1-20
-- but the number of records each legislator gets depends on their total terms
-- this is how the generate series can be utilized

SELECT a.*, b.*
FROM     
        (SELECT
            id_bioguide,
            DATE_PART('century',MIN(term_start)) AS first_century,
            COUNT(term_start) AS total_terms
        FROM legislators_terms
        GROUP BY 1) a
JOIN 
        (SELECT generate_series AS terms
         FROM generate_series(1,20,1)) b
    ON 1 = 1
WHERE a.first_century = 18 AND a.total_terms >= b.terms
ORDER BY a.id_bioguide

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- here is our aggregation
-- since we group on century and terms, every legislator will have a 1 value in terms, so this acts as our starting cohort size
-- the reason the starting size stays constant in the cohort column is because the id_bioguide comes from table a 

SELECT
    a.first_century,
    b.terms,
    COUNT(DISTINCT a.id_bioguide) AS cohort,
    COUNT(DISTINCT CASE WHEN a.total_terms >= b.terms THEN a.id_bioguide END) AS cohort_survived

FROM     
        (SELECT
            id_bioguide,
            DATE_PART('century',MIN(term_start)) AS first_century,
            COUNT(term_start) AS total_terms
        FROM legislators_terms
        GROUP BY 1) a
JOIN 
        (SELECT generate_series AS terms
         FROM generate_series(1,20,1)) b
    ON 1 = 1
GROUP BY 1,2

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT 
    DATE_PART('century',a.first_term) AS cohort_century,
    COUNT(DISTINCT a.id_bioguide) AS reps
FROM
    (SELECT
        id_bioguide,
        MIN(term_start) AS first_term
    FROM legislators_terms
    WHERE term_type = 'rep'
    GROUP BY 1) a
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- so in the subquery we get every legislator and their first term start when their first term is a rep
-- inner joining only the cases when those legislators (from the subquery) also had a term type sen and that term type was after their first term
-- so basically everything packaged together from the FROM and JOIN clause is narrowed down to these legislators
-- because the narrowed down conditions are part of your join, if you left joined you'd get back all the legislators from the subquery with nulls

SELECT 
    DATE_PART('century',a.first_term) AS cohort_century,
    COUNT(DISTINCT a.id_bioguide) AS reps
FROM
    (SELECT
        id_bioguide,
        MIN(term_start) AS first_term
    FROM legislators_terms
    WHERE term_type = 'rep'
    GROUP BY 1) a
JOIN legislators_terms b
    ON a.id_bioguide = b.id_bioguide
    AND b.term_type = 'sen' AND b.term_start > a.first_term
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- this shows you what results you get before the aggregation
-- if you left join instead of inner joing you'll see the difference (brings results from 11968 to 1397)
-- knowing how much you're filtering down using a JOIN with AND is crucial 

SELECT
    a.id_bioguide,
    a.first_term,
    b.term_type,
    b.term_start
FROM
    (SELECT
        id_bioguide,
        MIN(term_start) AS first_term
    FROM legislators_terms
    WHERE term_type = 'rep'
    GROUP BY 1) a
LEFT JOIN legislators_terms b
    ON a.id_bioguide = b.id_bioguide
    AND b.term_type = 'sen' AND b.term_start > a.first_term

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- back to the bigger query
-- this is actually straightforward
-- the first subquery is a count of the legislators grouped by the century of their first term, with the condition that they had a term as rep
-- the second subquery is the same count of legislators but under the condition that they also had a sen term and it was after their first term
-- then simple aggregation to find the percent grouped by century

SELECT
    aaa.cohort_century,
    ROUND(bbb.rep_and_sen / aaa.reps :: DECIMAL , 4) AS pct_rep_and_sen
FROM 
    (SELECT 
        DATE_PART('century',a.first_term) AS cohort_century,
        COUNT(DISTINCT a.id_bioguide) AS reps
    FROM
        (SELECT
            id_bioguide,
            MIN(term_start) AS first_term
        FROM legislators_terms
        WHERE term_type = 'rep'
        GROUP BY 1) a
    GROUP BY 1) aaa
 LEFT JOIN 
    (SELECT 
        DATE_PART('century',a.first_term) AS cohort_century,
        COUNT(DISTINCT a.id_bioguide) AS rep_and_sen
    FROM
        (SELECT
            id_bioguide,
            MIN(term_start) AS first_term
        FROM legislators_terms
        WHERE term_type = 'rep'
        GROUP BY 1) a
    JOIN legislators_terms b
        ON a.id_bioguide = b.id_bioguide
        AND b.term_type = 'sen' AND b.term_start > a.first_term
    GROUP BY 1) bbb
ON aaa.cohort_century = bbb.cohort_century

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- in order to make a more fair comparison, we have to consider the legislators who were elected somewhat recently and may be in office
-- we want those legislators removed for a fair cohort comparison
-- creating a time box of 10 years
-- the structure of the query is the same as previously, but we're limiting to legislators who became a sen within 10 years after first term
-- and also removing legislators who were elected after 2009 

SELECT
    aaa.cohort_century,
    ROUND(bbb.rep_and_sen / aaa.reps :: DECIMAL , 4) AS pct_10_years
FROM 
    (SELECT 
        DATE_PART('century',a.first_term) AS cohort_century,
        COUNT(DISTINCT a.id_bioguide) AS reps
    FROM
        (SELECT
            id_bioguide,
            MIN(term_start) AS first_term
        FROM legislators_terms
        WHERE term_type = 'rep'
        GROUP BY 1) a
    WHERE first_term <= '2009-12-31'
    GROUP BY 1) aaa
 LEFT JOIN 
    (SELECT 
        DATE_PART('century',b.first_term) AS cohort_century,
        COUNT(DISTINCT b.id_bioguide) AS rep_and_sen
    FROM
        (SELECT
            id_bioguide,
            MIN(term_start) AS first_term
        FROM legislators_terms
        WHERE term_type = 'rep'
        GROUP BY 1) b
    JOIN legislators_terms c
        ON b.id_bioguide = c.id_bioguide
        AND c.term_type = 'sen' AND c.term_start > b.first_term
    WHERE AGE(c.term_start, b.first_term) <= interval '10 years'
    GROUP BY 1) bbb
ON aaa.cohort_century = bbb.cohort_century

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- the only difference here is rather than just counting the rep -> sen who did it within 10 years
-- you're splitting that count into multiple time bounds with a case statement instead of filtering in the where
-- the outermost select is a straightforward percentage 

SELECT
    aa.cohort_century,
    ROUND (bb.rep_and_sen_5yrs * 1.0 / aa.reps,4) AS pct_5_yrs,
    ROUND (bb.rep_and_sen_10yrs * 1.0 / aa.reps,4) AS pct_10_yrs,
    ROUND (bb.rep_and_sen_15yrs * 1.0 / aa.reps, 4) AS pct_15_yrs
FROM    
   (SELECT 
        date_part('century',a.first_term) AS cohort_century,
        COUNT(a.id_bioguide) AS reps
    FROM
        (SELECT
            id_bioguide,
            MIN(term_start) AS first_term
         FROM legislators_terms
         WHERE term_type = 'rep'
         GROUP BY 1) a
    WHERE a.first_term <= '2009-12-31'
    GROUP BY 1) aa
LEFT JOIN
    (SELECT
        DATE_PART('century',b.first_term) AS cohort_century,
        COUNT(DISTINCT CASE WHEN AGE(c.term_start, b.first_term) <= INTERVAL '5 years' THEN b.id_bioguide END) AS rep_and_sen_5yrs,
        COUNT(DISTINCT CASE WHEN AGE(c.term_start, b.first_term) <= INTERVAL '10 years' THEN b.id_bioguide END) AS rep_and_sen_10yrs,
        COUNT(DISTINCT CASE WHEN AGE(c.term_start, b.first_term) <= INTERVAL '15 years' THEN b.id_bioguide END) AS rep_and_sen_15yrs
    FROM
       (SELECT
            id_bioguide,
            MIN(term_start) AS first_term
        FROM legislators_terms
        WHERE term_type = 'rep'
        GROUP BY 1) b
    JOIN legislators_terms c
        ON b.id_bioguide = c.id_bioguide
        AND c.term_type = 'sen' AND c.term_start > b.first_term
    GROUP BY 1) bb
ON aa.cohort_century = bb.cohort_century

---------------------------------------------------- Cumulative Calculations -----------------------------------------------------------------------------

-- cumulative lifetime value aka customer lifetime value
-- users of the service who return frequently in the first few days or weeks tend to be the most likely to stay around over the long haul
-- with cumulative calculations were less concerned with "did a customer do an action on a particular date"
-- and more concerned with "what the total order amount is at a particular date"
-- again apples to apples comparison with time box limiting
-- ex. average actions per customer, average order value, items per order, orders per customer etc
-- customer lifetime value calculations, calculated as total dollars spent or gross margin
-- or similarly with defined periods like 3 years 5 years 10 years

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- in the subquery we're assigning a type value to each legislator according to their first term type
-- along with that first start term date and the date 10 years later
-- left joining back to it to get all the start terms dates that fall within that 10 year window
-- so the resulting outer query is a count of all legislators by century started and type started
-- and a count of all the terms happened within 10 years of each legislators first term

SELECT
    DATE_PART('century', a.first_term) AS century,
    first_type,
    COUNT(DISTINCT a.id_bioguide) AS cohort,
    COUNT(b.term_start) AS terms,
    ROUND(COUNT(b.term_start) / COUNT(DISTINCT a.id_bioguide) :: DECIMAL,1) AS avg_terms_per_legis
FROM
        (SELECT
            DISTINCT id_bioguide,
            FIRST_VALUE(term_type) OVER (PARTITION BY id_bioguide ORDER BY term_start) AS first_type,
            MIN(term_start) OVER (PARTITION BY id_bioguide) AS first_term,
            MIN(term_start) OVER (PARTITION BY id_bioguide) + INTERVAL '10 years' AS first_plus_10
        FROM legislators_terms) a
LEFT JOIN legislators_terms b
    ON a.id_bioguide = b.id_bioguide
    AND b.term_start BETWEEN a.first_term AND a.first_plus_10
GROUP BY 1,2
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- essentially the same information just pivoted with case statements, keeping century as the group by returning as records

SELECT 
    century,
    MAX(CASE WHEN first_type = 'rep' THEN cohort END) AS rep_cohort,
    ROUND(MAX(CASE WHEN first_type = 'rep' THEN terms_per_legis END),1) AS avg_rep_terms,
    MAX(CASE WHEN first_type = 'sen' THEN cohort END) AS sen_cohort,
    ROUND(MAX(CASE WHEN first_type = 'sen' THEN terms_per_legis END),1) AS avg_sen_terms
FROM
        (SELECT
            DATE_PART('century', a.first_term) AS century,
            first_type,
            COUNT(DISTINCT a.id_bioguide) AS cohort,
            COUNT(b.term_start) AS terms,
            ROUND(COUNT( b.term_start) / COUNT(DISTINCT a.id_bioguide) :: DECIMAL, 4) AS terms_per_legis
        FROM
                (SELECT
                    DISTINCT id_bioguide,
                    FIRST_VALUE(term_type) OVER (PARTITION BY id_bioguide ORDER BY term_start) AS first_type,
                    MIN(term_start) OVER (PARTITION BY id_bioguide) AS first_term,
                    CAST(MIN(term_start) OVER (PARTITION BY id_bioguide) + INTERVAL '10 years' AS DATE) AS first_plus_10
                FROM legislators_terms) a
        LEFT JOIN legislators_terms b
            ON a.id_bioguide = b.id_bioguide
            AND b.term_start BETWEEN a.first_term AND a.first_plus_10
        GROUP BY 1,2) aa
GROUP BY 1

------------------------------------------- Cross Sectional Analysis Through Cohort Lens------------------------------------------------------------------

-- it can become hard to spot changes in the overall composition of a customer or user base
-- max shifts: changes in the composition of the customers or user base over time, making later cohorts different from earlier ones
-- they can be a byproduct of changes in the organization, broadening 
-- to detect possible max shifts, create additional cohorts along suspected lines to try to diagnosis
-- cross sectional analysis differs from cohort analysis, it compares individuals or groups at a single point in tme
-- this analysis can be insightful and help generate hypotheses for further investigation, they are easier to run since no time series is needed
-- however cross sectional analysis is suseptible to survivorship bias
-- survivorship bias is a logical error of focusing on the people that made past some selected process while ignoring those who didn't
-- not all entities exist in the data that did at the start, the customers you're analyzing might only be your best customers
-- this leads to overoptimistic conclusions
-- cohort analysis will not have survivorship bias because all members from the start are considered
-- however we can take a series of cross sections from a cohort analysis to understand and detect max shifts and how entities change over time

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- returns the number of legislators who held office during each 12-31

SELECT
    b.date,
    COUNT(DISTINCT a.id_bioguide) AS legislators
FROM legislators_terms a
JOIN date_dim b
  ON b.date BETWEEN a.term_start AND a.term_end
  AND b.month_name = 'December' AND b.day_of_month = 31
  AND b.year <=2019
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- now we add the century cohorting criteria
-- like the previous query, but since we're also grouping by century
-- we'll get a two records for a year when some legislators started in one century and some legislators started in another

SELECT
    b.date,
    DATE_PART('century',c.first_term) AS century,
    COUNT(DISTINCT a.id_bioguide) AS legislators
FROM legislators_terms a
JOIN date_dim b
  ON b.date BETWEEN a.term_start AND a.term_end
  AND b.month_name = 'December' AND b.day_of_month = 31
  AND b.year <=2019
JOIN 
        (SELECT 
            id_bioguide,
            MIN(term_start) AS first_term 
        FROM legislators_terms
        GROUP BY 1) c
  ON a.id_bioguide = c.id_bioguide
GROUP BY 1,2

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- taking this one step further we return everything from the subquery
-- but also use a window function to have a total number of legislators on a given date regardless of what century they started in
-- having the values in this column allows us to calculate the percent of total
-- for example, what percent of the total legislators in office on 1905-12-31 started out in the 19th century compared to 20th century

SELECT
    date,
    century,
    legislators,
    SUM(legislators) OVER (PARTITION BY date) AS cohort,
    ROUND(legislators / SUM(legislators) OVER (PARTITION BY date),4) AS pct_century
FROM
        (SELECT
            b.date,
            DATE_PART('century',c.first_term) AS century,
            COUNT(DISTINCT a.id_bioguide) AS legislators
        FROM legislators_terms a
        JOIN date_dim b
          ON b.date BETWEEN a.term_start AND a.term_end
          AND b.month_name = 'December' AND b.day_of_month = 31
          AND b.year <=2019
        JOIN 
                (SELECT 
                    id_bioguide,
                    MIN(term_start) AS first_term
                FROM legislators_terms
                GROUP BY 1) c
          ON a.id_bioguide = c.id_bioguide
        GROUP BY 1,2) a
ORDER BY date DESC

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- same results, different output view
-- this output translates well into a 100% stacked line chart

SELECT
    date,
    COALESCE(ROUND((SUM(CASE WHEN century = 18 THEN legislators END) / SUM(legislators)),4),0) AS pct_18,
    COALESCE(ROUND((SUM(CASE WHEN century = 19 THEN legislators END) / SUM(legislators)),4),0) AS pct_19,
    COALESCE(ROUND((SUM(CASE WHEN century = 20 THEN legislators END) / SUM(legislators)),4),0) AS pct_20,
    COALESCE(ROUND((SUM(CASE WHEN century = 21 THEN legislators END) / SUM(legislators)),4),0) AS pct_21
FROM
        (SELECT
            b.date,
            DATE_PART('century',c.first_term) AS century,
            COUNT(DISTINCT a.id_bioguide) AS legislators
        FROM legislators_terms a
        JOIN date_dim b
          ON b.date BETWEEN a.term_start AND a.term_end
          AND b.month_name = 'December' AND b.day_of_month = 31
          AND b.year <=2019
        JOIN 
                (SELECT 
                    id_bioguide,
                    MIN(term_start) AS first_term
                FROM legislators_terms
                GROUP BY 1) c
          ON a.id_bioguide = c.id_bioguide
        GROUP BY 1,2) a
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- same concept but cohorting on tenure in office instead of century started
-- inner query gets you a record for every 12-31 date that every legislator was in office
-- we're looking for the cumulative number of years in office for each legislator
-- (learn about the rows between here)

SELECT
    id_bioguide,
    date,
    COUNT(date) OVER (PARTITION BY id_bioguide ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cume_years
FROM 
        (SELECT
            DISTINCT a.id_bioguide,
            b.date
        FROM legislators_terms a
        JOIN date_dim b
          ON b.date BETWEEN a.term_start AND a.term_end
          AND b.month_name = 'December' AND b.day_of_month = 31
          AND b.year <=2019
          ORDER BY 1) aa
          
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- now with another outer query we can group our count by date and cume_years
-- tells us: on a particular 12-31 date how many legislators in office had accululated 1 year of office, how many accumulated 2 years etc.

SELECT
    date,
    cume_years,
    COUNT(DISTINCT id_bioguide) AS legislators
FROM
        (SELECT
            id_bioguide,
            date,
            COUNT(date) OVER (PARTITION BY id_bioguide ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cume_years
        FROM 
                (SELECT
                    DISTINCT a.id_bioguide,
                    b.date
                FROM legislators_terms a
                JOIN date_dim b
                  ON b.date BETWEEN a.term_start AND a.term_end
                  AND b.month_name = 'December' AND b.day_of_month = 31
                  AND b.year <=2019) aa) aaa
GROUP BY 1,2
ORDER BY 1,2

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- looking at the query tells us that some years have a variety of different tenures 
-- meaning some legislators have accumulated 1 year of office, some have accumulated all the way up 30 years of office
-- this isn't too useful for graphing purposes

SELECT
    date,
    COUNT(*) AS tenures
FROM      
        (SELECT
            date,
            cume_years,
            COUNT(DISTINCT id_bioguide) AS legislators
        FROM
                (SELECT
                    id_bioguide,
                    date,
                    COUNT(date) OVER (PARTITION BY id_bioguide ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cume_years
                FROM 
                        (SELECT
                            DISTINCT a.id_bioguide,
                            b.date
                        FROM legislators_terms a
                        JOIN date_dim b
                          ON b.date BETWEEN a.term_start AND a.term_end
                          AND b.month_name = 'December' AND b.day_of_month = 31
                          AND b.year <=2019) aa) aaa
        GROUP BY 1,2) aaaa
GROUP BY 1
ORDER BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- instead we can break the cumulative years into bins, so we no longer have a record for every possible cumulative year
-- its good to create 3-5 groups of equal size
-- this makes graphing the output feasible
-- so our output from here displays information related to cross sectional analysis 

SELECT
    TO_CHAR(date,'YYYY-MM-DD'),
    tenure,
    legislators / SUM(legislators) OVER (PARTITION BY date) AS pct_legislators
FROM
        (SELECT
            date,
            CASE WHEN cume_years BETWEEN 1 AND 4 THEN '1 to 4'
                 WHEN cume_years BETWEEN 5 AND 10 THEN '5 to 10'
                 WHEN cume_years BETWEEN 11 AND 20 THEN '11 to 20'
                 WHEN cume_years >= 21 THEN '21+' END AS tenure,
            COUNT(DISTINCT id_bioguide) AS legislators
        FROM
                (SELECT
                    id_bioguide,
                    date,
                    COUNT(date) OVER (PARTITION BY id_bioguide ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cume_years
                FROM 
                        (SELECT
                            DISTINCT a.id_bioguide,
                            b.date
                        FROM legislators_terms a
                        JOIN date_dim b
                          ON b.date BETWEEN a.term_start AND a.term_end
                          AND b.month_name = 'December' AND b.day_of_month = 31
                          AND b.year <=2019) aa) aaa
        GROUP BY 1,2) aaaa
ORDER BY 1 DESC
----------------------------------------------------------------------------------------------------------------------------------------------------------
