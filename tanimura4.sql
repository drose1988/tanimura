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

-- retention is concerned with whether the cohort member has a record in the time series on a particular date, expressed in number of periods from start date
-- survivorship is concerned with how many entities remained in the data set for a certain length of time, regardless of frequency of actions in that time
-- returnship is concerned with whether an action has happened more than a minimum threshold of times, like more than once over a specific window of time
-- cumulative calculations the total number or amount measured at one or more fixed time windows, regardless of when they happened

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
-- this window function is saying 'get next record of term_start of the same id_bioguide, next record will be according to the order of term_start '
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
-- 

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
----------------------------------------------------------------------------------------------------------------------------------------------------------

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
----------------------------------------------------------------------------------------------------------------------------------------------------------
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
----------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    DISTINCT id_bioguide,
    term_type,
    DATE('2000-01-01') AS first_term,
    MIN(term_start) AS min_start
FROM legislators_terms
WHERE term_start <= '2000-12-31' AND term_end >= '2000-01-01'
GROUP BY 1,2,3
----------------------------------------------------------------------------------------------------------------------------------------------------------
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
----------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    DISTINCT id_bioguide,
    MIN(term_start) AS first_term,
    MAX(term_start) AS last_term
FROM legislators_terms
GROUP BY 1
----------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    DISTINCT id_bioguide,
    DATE_PART('century',MIN(term_start)) AS first_century,
    MIN(term_start) AS first_term,
    MAX(term_start) AS last_term,
    DATE_PART('year',AGE(MAX(term_start),MIN(term_start))) AS tenure
FROM legislators_terms
GROUP BY 1
----------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    first_century AS century,
    COUNT(DISTINCT id_bioguide) AS cohort_size,
    COUNT(DISTINCT CASE WHEN tenure >= 10 THEN id_bioguide ELSE NULL END) AS survived_10,
    ROUND(COUNT(DISTINCT CASE WHEN tenure >= 10 THEN id_bioguide ELSE NULL END) / COUNT(DISTINCT id_bioguide) :: DECIMAL, 4) AS pct_survived_10
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
SELECT * 
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
SELECT
    aa.cohort_century,
    ROUND (rep_and_sen_5yrs * 1.0 / reps,4) AS pct_5_yrs,
    ROUND (rep_and_sen_10yrs * 1.0 / reps,4) AS pct_10_yrs,
    ROUND (rep_and_sen_15yrs * 1.0 / reps, 4) AS pct_15_yrs
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
----------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    DATE_PART('century', a.first_term) AS century,
    first_type,
    COUNT(DISTINCT a.id_bioguide) AS cohort,
    COUNT(b.term_start) AS terms
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
SELECT 
    century,
    MAX(CASE WHEN first_type = 'rep' THEN cohort END) AS rep_cohort,
    ROUND(MAX(CASE WHEN first_type = 'rep' THEN terms_per_leg END),1) AS avg_rep_terms,
    MAX(CASE WHEN first_type = 'sen' THEN cohort END) AS sen_cohort,
    ROUND(MAX(CASE WHEN first_type = 'sen' THEN terms_per_leg END),1) AS avg_sen_terms
FROM
        (SELECT
            DATE_PART('century', a.first_term) AS century,
            first_type,
            COUNT(DISTINCT a.id_bioguide) AS cohort,
            COUNT(b.term_start) AS terms,
            ROUND(COUNT( b.term_start) / COUNT(DISTINCT a.id_bioguide) :: DECIMAL, 4) AS terms_per_leg
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
----------------------------------------------------------------------------------------------------------------------------------------------------------
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
          AND b.year <=2019) aa
----------------------------------------------------------------------------------------------------------------------------------------------------------
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
GROUP BY 1,2;
----------------------------------------------------------------------------------------------------------------------------------------------------------
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


