----------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------- Building Complex Data Sets -----------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- goal of a query is to assemble a data set that is specific enough yet general purpose enough to be used for variety of further analyses
-- code is likely to change over time as stakeholders request additional data points

--------------------------------------------------- When to use SQL for Complex Data Sets-----------------------------------------------------------------

-- the manipulation and wrangling you do in sql queries creates logic
-- the question is where we want to store this logic: 
-- keep in the sql query, push the logic upstream with ETL (extract transform load), or push logic downstream to R, Python, Excel, BI tools
-- keeping sql logic within the code is ideal when working on a new analysis, or any logic expected to undergo frequent range

------------------------------------------------------- When to Build into ETL ---------------------------------------------------------------------------

-- reasons to move logic upstream are performance and visibility
-- long complicated queries will cause query slow down and tax your server
-- ETL runs behind the scenes at schedules times (could be by the hour or overnight)
-- developing ETL for storing daily snapshot results 
-- storing in ETL rather keeping in sql queries makes logic more accessible and visible to other people
-- difficulties for other people to find the logic buried in code or on someone elses computer
-- however going this route has downsides
-- fresh results are not available until the ETL job has run and refreshed the data
-- less flexibility and ability to modify ETL changes compared to sql queries
-- good idea to wait until sql queries are past the period of rapid iteration and results have been reviewed, then move to ETL

--------------------------------------------------------------- Views ------------------------------------------------------------------------------------

-- view is essentially a saved query with permanent alisas that can be referenced like another table
-- they can shield users from the complexity of underlying query 
-- can provide an extra layer of security
-- technically views are objects in the database so they do require permission to create and update

------------------------------------------------ When to Move Logic to Other Tools -----------------------------------------------------------------------

-- embedding sql results in reports, visualizations, dashboards, further manipulation tools, spreadsheets, BI software
-- good rule to perform as much calculation as possible in the database and only what you need in spreadsheets - leverage power of the db
-- language like Python and R are equipt to perfrom statistical and machine learning analysis as well as overlapping with sql on features
-- avoid manual steps and keep your code documented somewhere
-- iterating (repeating a process) will most likely be needed on an analysis and accessing your logic is crutial 
-- when new data arrives, or you have to make modifcations, or stakeholder has a request, you want all the steps you used visible
-- deciding between ETL, queries, downstream for your logic is a trial and error thing and you iterate through the process

------------------------------------------------------ Organizational Computation ------------------------------------------------------------------------

-- 3 ways to organize the intermediate results: subquery, temporary table, common table expressions (CTE)
-- SQL order of evaluation: FROM (including JOIN and ONs), WHERE, GROUP BY, HAVING, window functions, SELECT, DISTINCT, UNION, ORDER BY, LIMIT or OFFSET
-- aggregators return a numeric value with the exception of MIN and MAX which return the original data type

-- lateral subquery: an exception to the standalone nature of subqueries, it can access previous items in the FROM clause
-- type in LATERAL instead of JOIN and include a comma before lateral
-- in this example, subquery c references subquery a, subquery c wouldn't run as a standalone query 

SELECT
    DATE_PART('year', c.first_term) AS first_year,
    a.party,
    COUNT(a.id_bioguide) AS legislators
FROM 
        (SELECT
            DISTINCT id_bioguide, party
         FROM legislators_terms
         WHERE term_end > '2020-06-01') a,
LATERAL 
        (SELECT 
            b.id_bioguide,
            MIN(term_start) AS first_term
         FROM legislators_terms b
         WHERE a.id_bioguide = b.id_bioguide
          AND a.party <> b.party
         GROUP BY 1) c
GROUP BY 1,2

---- Temporary Tables ------------------------------------------------------------------------------------------------------------------------------------
        
-- temp tables are useful when working with a small part of a very large dataset
-- when you create a temp table you can write the data which you may not have access to do, this method allows requires you specify data types
-- or you could "create as" method automatically assigns the data type based on the type from the select statement, there is no primary key

---- Common Table Expressions ----------------------------------------------------------------------------------------------------------------------------

-- think of CTEs as subqueries but lifted out and placed at the beginning of the query execution
-- the logic moves downwards rather than outwards (like with subqueries nesting in each other)
-- could be a better way to organize longer code, easier on the eyes
-- however this method makes checking the intermediate steps harder compared to subquerying 
-- useful way to control the order of evaluation

WITH first_term AS
        (SELECT id_bioguide, MIN(term_start) AS first_term
        FROM legislators_terms
        GROUP BY 1)
SELECT
    DATE_PART('year', AGE(b.term_start, a.first_term)) AS periods,
    COUNT(DISTINCT a.id_bioguide) AS cohort_retained
FROM first_term a
JOIN legislators_terms b
  ON a.id_bioguide = b.id_bioguide
GROUP BY 1

---- Grouping Sets ---------------------------------------------------------------------------------------------------------------------------------------

-- this is a good alternative to using UNION
-- 3 options to include after GROUP BY are grouping sets, cube, rollup

-- this method of UNION with NULLs is a technique to aggregate global_sales on platform, genre, publisher but as standalone aggregations
-- this is different from grouping sales by the combinations of platform, genre, publisher

SELECT
    platform,
    NULL AS genre,
    NULL AS publisher,
    SUM(global_sales) AS global_sales
FROM videogame_sales
GROUP BY 1,2,3
    UNION
SELECT
    NULL AS platform,
    genre,
    NULL AS publisher,
    SUM(global_sales) AS global_sales
FROM videogame_sales
GROUP BY 1,2,3
    UNION
SELECT
    NULL AS platform,
    NULL AS genre,
    publisher,
    SUM(global_sales) AS global_sales
FROM videogame_sales
GROUP BY 1,2,3

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- this query has the same return but using grouping sets makes the code much more compact

SELECT 
    platform,
    genre,
    publisher,
    SUM(global_sales) AS global_sales
FROM videogame_sales
GROUP BY grouping sets (platform, genre, publisher)

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- by adding a blank to the grouping set, we get the same return back but additionally a record for summed global_sales for All/All/All

SELECT
    COALESCE(platform, 'All') AS platform,
    COALESCE(genre, 'All') AS genre,
    COALESCE(publisher, 'All') AS publisher,
    SUM(global_sales) AS na_sales
FROM videogame_sales
GROUP BY grouping sets ((),platform, genre, publisher)

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- cube calculates all possible combinations of the fields you specify in the GROUP BY 

SELECT
    COALESCE(platform, 'All') AS platform,
    COALESCE(genre, 'All') AS genre,
    COALESCE(publisher, 'All') AS publisher,
    SUM(global_sales) AS na_sales
FROM videogame_sales
GROUP BY cube (platform, genre, publisher)

-- rollup is similar but the return depends on the ordering of your fields in the parentheses
-- for example this query returns an aggregation for all combinations of platform/genre/publisher, platform/genre, platform
-- but will exclude the combinations of platform/publisher, genre/publisher, genre, publisher

SELECT
    COALESCE(platform, 'All') AS platform,
    COALESCE(genre, 'All') AS genre,
    COALESCE(publisher, 'All') AS publisher,
    SUM(global_sales) AS na_sales
FROM videogame_sales
GROUP BY rollup (platform, genre, publisher)

----------------------------------------------------- Reducing Dimensionality  ---------------------------------------------------------------------------

-- a common dilemma is having to balance the size of the data set while also providing as many different attributes and retaining as much info as possible
-- adjusting the granularity of the data
-- best place to start here is reducing the granularity of dates and times
-- also restricting your data set by a certain length of time, if long term trends are not of concern
-- reduce granularity of the data by cleaning text, so there are less distinct value to aggregate on 
-- use case statements to limit the distinct values of a field if only a handful of values of a list are relevant for analysis
-- for example if you're concerned with only the top US states and are willing to relabel everything else Other

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    CASE WHEN state IN ('CA','FL','TX','NY','PA') THEN state ELSE 'Other' END AS state_group,
    COUNT(*) AS terms
FROM legislators_terms
GROUP BY 1
ORDER BY 2 DESC

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- or rank the values in the subquery, so how many unique legislators in each state and the rank of that count
-- then use those ranks for your case statement, only the top 5 states get their own record and the rest get grouped to Other 

SELECT
    CASE WHEN b.rank <=5 THEN a.state ELSE 'Other' END AS state_group,
    COUNT(DISTINCT id_bioguide) AS legislators
FROM legislators_terms a 
JOIN
        (SELECT
            state,
            COUNT(DISTINCT id_bioguide),
            RANK() OVER (ORDER BY COUNT(DISTINCT id_bioguide) DESC)
        FROM legislators_terms
        GROUP BY 1) b
ON a.state = b.state
GROUP BY 1
ORDER BY 2 DESC

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- flagging is a similar method to reduce dimensionality 
-- useful when hitting a threshold is of importance but not necessarily the value beyond that threshold

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- flagging with a true false option

SELECT
    CASE WHEN a.terms >= 2 THEN true ELSE false END AS two_term_flag,
    COUNT(*) AS legislators
FROM
        (SELECT
            id_bioguide,
            COUNT(term_id) AS terms
        FROM legislators_terms
        GROUP BY 1) a
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- or flagging on several levels if true/false isn't informative enough
-- trial and error will help you establish the right threshold

SELECT
    CASE WHEN terms >= 10 THEN '10+'
         WHEN terms >= 2 THEN '2 - 9'
         WHEN terms >= 1 THEN '1'
         END AS terms_level,
    COUNT(*) AS legislators
FROM
        (SELECT
            id_bioguide,
            COUNT(term_id) AS terms
        FROM legislators_terms
        GROUP BY 1) a
GROUP BY 1

------------------------------------------------------- PII and Data Privacy -----------------------------------------------------------------------------

-- we need to be mindful of the ethical and regulatory dimensions of how data is collected and used
-- regulation around data privacy is advancing and you need to comply with these regulations
-- personally identifiable information include a number of sensitive categories (identity, health, location)
-- avoid including PII itself in the outputs by aggregating, substituting values, or hashing
-- avoiding PII in your output is always a best practice

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- use ROW_NUMBER window function to assign a new unique value to an entity so we can reference that instead of a PII field

SELECT 
    DISTINCT id_bioguide,
    ROW_NUMBER() OVER (ORDER BY term_start)
FROM legislators_terms

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- MD5 function generates a hashed value - unique random value 

SELECT 
    DISTINCT id_bioguide,
    MD5(id_bioguide)
FROM legislators_terms

----------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------ Conclusion ----------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------- Funnel Analysis --------------------------------------------------------------------------

-- funnel consists of a series of steps that must be completed to reach a defined goal
-- combines elements of time series analysis and cohort analysis
-- you're essentially measuring retention at each step of the funnel all the way to the end (conversion)
-- this type of analysis is used to identify areas of friction, difficulty, confusion for users
-- and provide insights into the possible solutions or optimizations to address the issues

-- 1st step: figure out the base population (all entities eligable to enter the process)
-- 2nd step: assemble dataset of completion for each step of interest
-- 3rd step: get a count of entities at each step along with the starting total, also a pct of entities completing the step over the starting total
-- two methods for calculating percent: percent of total, percent of previous step 

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- with just the count of users making it to each step

SELECT
    COUNT(a.user_id) AS all_users,
    COUNT(b.user_id) AS users_to_step_one,
    COUNT(c.user_id) AS users_to_step_two,
    COUNT(d.user_id) AS users_to_step_three
FROM users a
LEFT JOIN step_one b
  ON a.user_id = b.user_id
LEFT JOIN step_two c
  ON b.user_id = c.user_id
LEFT JOIN step_three b
  ON c.user_id = d.user_id
  
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- with the percent of users making it to each step

SELECT
    COUNT(a.user_id) AS all_users,
    COUNT(b.user_id) AS users_to_step_one,
    COUNT(b.user_id) / COUNT(a.user_id) AS pct_step_one,
    COUNT(c.user_id) AS users_to_step_two,
    COUNT(c.user_id) / COUNT(d.user_id) AS pct_step_two,
    COUNT(d.user_id) AS users_to_step_three,
    COUNT(d.user_id) / COUNT(c.user_id) AS pct_step_three
FROM users a
LEFT JOIN step_one b
  ON a.user_id = b.user_id
LEFT JOIN step_two c
  ON b.user_id = c.user_id
LEFT JOIN step_three b
  ON c.user_id = d.user_id

---------------------------------------------------------- Churn, Lapse (Departure) ----------------------------------------------------------------------

-- churn is essentially the opposite of retention
-- important to establish a good churn definition, like at what point the users are considered churned out (haven't interacted or purchased in 30 days)
-- customers churning don't always have to be churned from the company, it can be narrowed down to churning from a product or particular subsription
-- use gap analysis to find the periods between purchases or interaction with website/app

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    id_bioguide,
    term_start,
    LAG(term_start) OVER (PARTITION BY id_bioguide ORDER BY term_start) AS prev_term_start,
    AGE(term_start, LAG(term_start) OVER (PARTITION BY id_bioguide ORDER BY term_start)) AS gap_interval
FROM legislators_terms
WHERE term_type = 'rep'

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    AVG(gap_interval) AS avg_gap
FROM         
        (SELECT 
            id_bioguide,
            term_start,
            LAG(term_start) OVER (PARTITION BY id_bioguide ORDER BY term_start) AS prev_term_start,
            AGE(term_start, LAG(term_start) OVER (PARTITION BY id_bioguide ORDER BY term_start)) AS gap_interval
        FROM legislators_terms
        WHERE term_type = 'rep') a

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- starting with the subquery, we use the lag function like we've done before to get each legislators previous term_start date
-- and age function will give us the time between those two dates but in years, days, months, minutes etc.
-- so our goal is to find the number of months between the term_start dates
-- take the gap interval, extract the number of months in there, extract the number of years in there (*12 to convert to months) then add those two up
-- then we can count all the terms grouped by the gap in months

SELECT
    gap_months,
    COUNT(*)
FROM         
        (SELECT 
            id_bioguide,
            term_start,
            LAG(term_start) OVER (PARTITION BY id_bioguide ORDER BY term_start) AS prev_term_start,
            AGE(term_start, LAG(term_start) OVER (PARTITION BY id_bioguide ORDER BY term_start)) AS gap_interval,
            DATE_PART('year',AGE(term_start, LAG(term_start) OVER (PARTITION BY id_bioguide ORDER BY term_start))) * 12
            +
            DATE_PART('month',AGE(term_start, LAG(term_start) OVER (PARTITION BY id_bioguide ORDER BY term_start))) AS gap_months
        FROM legislators_terms
        WHERE term_type = 'rep') a
GROUP BY 1
ORDER BY 1

-- we can use this output to define our threshold for churning
-- this data thrown in a histogram will show us frequency of gap_months
-- so we can use the frequency to determine what an approapriate churn definition would be
-- the term "lapsed" is often used as an intermediate stage between active customers and churned customers

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- "time since last" analysis: find time elapsed since the date of the last action to the current date
-- in this case we find the last term start of each legislator, and the elapsed time between then and now
-- then we group based on the years of that elapsed time, to make the output more manageable
-- users that are labeled "lapsed" often get experimented on by the company through promotional, marketing, support outreach tactics

SELECT
    DATE_PART('years',interval_since_last) AS years_since_last,
    COUNT(*)
FROM 
        (SELECT
            id_bioguide,
            MAX(term_start) AS max_date,
            AGE(CURRENT_DATE, MAX(term_start)) AS interval_since_last
        FROM legislators_terms
        WHERE term_type = 'rep'
        GROUP BY 1) a
GROUP BY 1
ORDER BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- we can assign a status based on the months since last elected
-- this is using a case statement after two aggregation steps, so we're not assigning a status label to an individual legislator
-- instead we're finding all the unique number of months since last elected (which we assign the status label to) and a count of reps for each

SELECT
    months_since_last,
    CASE WHEN months_since_last <= 48 THEN 'Current'
         WHEN months_since_last <= 100 THEN 'Lapsed'
         ELSE 'Churned' END AS status,
    reps
FROM
        (SELECT
            DATE_PART('year',interval_since_last) *12
            +
            DATE_PART('months',interval_since_last) AS months_since_last,
            COUNT(*) AS reps
         FROM

                (SELECT
                    id_bioguide,
                    MAX(term_start) AS max_date,
                    AGE(CURRENT_DATE, MAX(term_start)) AS interval_since_last
                FROM legislators_terms
                WHERE term_type = 'rep'
                GROUP BY 1
                ORDER BY 1) a
         GROUP BY 1) aa

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- now the final aggregation of number of reps grouped by the status label
-- this uses sum not count, view the previous query, we don't want a count of reps per status because reps has already been aggregated, so we sum up reps

SELECT
    CASE WHEN months_since_last <= 48 THEN 'Current'
         WHEN months_since_last <= 100 THEN 'Lapsed'
         ELSE 'Churned' END AS status,
    SUM(reps) AS total_reps
FROM
        (SELECT
            DATE_PART('year',interval_since_last) *12
            +
            DATE_PART('months',interval_since_last) AS months_since_last,
            COUNT(*) AS reps
         FROM

                (SELECT
                    id_bioguide,
                    MAX(term_start) AS max_date,
                    AGE(CURRENT_DATE, MAX(term_start)) AS interval_since_last
                FROM legislators_terms
                WHERE term_type = 'rep'
                GROUP BY 1
                ORDER BY 1) a
         GROUP BY 1) aa
GROUP BY 1

-- churn analysis is very important to businesses because of how valuable retaining customers is
-- we can further slice the customers in the data set based on certain attributes when doing churn analysis

--------------------------------------------------------------- Basket Analysis---------------------------------------------------------------------------

-- basket analysis is analyzing patterns in consumer purchases, analyzing products consumers buy together
-- concept doesn't just apply to a single tranaction
-- it can be extended in a number of ways like examining the basket of items a customer has purchased in their lifetime with the company
-- used for future marketing, bundling product discount, apply suggestions based on what they're buying and what its frequency basketed with
-- use the string_agg function with a group by
-- this inner query gives you all the names of products in one field seperated by a comma grouped by the customer
-- then the outer query looks at each combination of products and counts the number of customers per combination of purchases

SELECT
    products,
    COUNT(customer_id) AS customers
FROM 
        (SELECT 
            customer_id,
            string_agg(product,', ') AS products
         FROM purchases
         GROUP BY 1) a
GROUP BY 1
ORDER BY 2 DESC

-- this method could be troublesome if there are a large catalog of products, services etc
-- the combinations of products ordered by customers can lead to a long output
-- maybe remove the most common items purchased in the where clause to give the query more meaning

----------------------------------------------------------------------------------------------------------------------------------------------------------
