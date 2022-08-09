----------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------- TIME SERIES ANALYSIS ----------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- aspects of time series data are so prevalent and important in many types of analyses
-- time series analysis: understand and quantify how things change over time
-- forcasting is the common goal, however the past doesn't perfectly predict the future





-- many databases are set to UTC the global standard, its the most common but certainly not universal
-- the one drawback to UTC is that we lose information about the local time humans do actions 

SELECT '2020-09-01 00:00:00 -0' at time zone 'pst'; -- changing from UTC to PST

---------------------------------------------- DATE, DATETIME, AND TIME MANIPULATION  --------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- transforming raw data format for our output

------------------------------------------------------- TIME ZONE CONVERSION  ----------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- many databases are set to UTC the global standard, its the most common but certainly not universal
-- the one drawback to UTC is that we lose information about the local time humans do actions 
-- all local times have a UTC offset 

-- at time zone: change from UTC to a chosen time zone

SELECT '2020-09-01 00:00:00 -0' at time zone 'pst';


SELECT current_date;

SELECT localtimestamp;

SELECT now();

SELECT current_time;

SELECT localtime;

SELECT timeofday();

-- all databases have time zone infomation systems table

SELECT * FROM pg_timezone_names -- postgres
SELECT * FROM mysql.timezone_names -- mysql
SELECT * FROM sys.time_zone_info -- sql server
SELECT * FROM pg_timezone_names -- redshift

--------------------------------------------------------- FORMAT CONVERSIONS  ----------------------------------------------------------------------------

-- dates and timestamps are the key to time series analysis
-- changing data type, extracting parts of a date or timestamp, creating a date or timestamp
-- these are essential types of conversions working with sql

-- DATE_TRUNC: function to reduce the granularity of a timestamp, similar to DATE_FORMAT in mysql

SELECT date_trunc('year', '2020-10-04 12:33:35' :: timestamp);
SELECT date_trunc('month', '2020-10-04 12:33:35' :: timestamp);
SELECT date_trunc('day', '2020-10-04 12:33:35' :: timestamp);

-- DATE_PART: returns a text value for the part to be returned of a date/timestamp
-- returns a float, may want to cast it to an integer
-- most common date parts: day, month, year, second, minute, hour

SELECT date_part('day',current_timestamp);
SELECT date_part('month',current_timestamp);
SELECT date_part('year',current_timestamp) :: INTEGER;
SELECT date_part('quarter',current_timestamp);
SELECT date_part('week',current_timestamp) :: INTEGER;
SELECT date_part('hour',current_timestamp);
SELECT date_part('minute',current_timestamp);

-- using DATE_PART and EXTRACT with INTERVAL (your interval must be matching units with the request part)

SELECT date_part('day',INTERVAL '30 days');
SELECT extract('day' FROM INTERVAL '30 days');

-- TO CHAR: to return text values of the date parts

SELECT to_char(current_timestamp, 'Day');
SELECT to_char(current_timestamp, 'Month');

-- concatenating two timestamps together or date + timestamp

SELECT date '2020-09-01' + time '03:00:00' as timestamp;

-- assembling dates
-- there are options, different functions output the same thing
-- make data requires integers in the argument

SELECT make_date(2020,09,01);
SELECT to_date(CONCAT(2020,'-',09,'-',01),'yyyy-mm-dd');
SELECT cast(concat(2020,'-',09,'-',01) as date);

------------------------------------------------------------- DATE MATH ----------------------------------------------------------------------------------

-- involves two types of data: the dates themselves and intervals
-- intervals are needed because date and times don't behave like integers

SELECT date('2020-05-31') - date('2020-06-30') as days;

-- datediff is not supported by postgres, but you can use the age function to calculate the interval between two dates

SELECT age(date('2020-06-30'), date('2016-01-31')); -- returns as "4 years 4 months 30 days"

-- to do addition with dates we need to leverage intervals

SELECT date('2020-07-31') + interval '7 days' as date;
SELECT date('2020-07-31') + interval '7 months';

-- some databases don't require interval syntax, though its a good idea for cross compatibility 

SELECT date('2020-07-31') +  7 days;

-- DATE_ADD or DATEADD

------------------------------------------------------------- TIME MATH ----------------------------------------------------------------------------------

-- whenever the elapsed time between two events is less than a day
-- or rounding to number of days doesn't provide enough information, time manipulation comes into play

SELECT time '05:00' + interval '3 hours' as new_time;
SELECT time '05:00' - interval '3 hours' as new_time;
SELECT time '05:00' - time '03:00' as new_time;

-- times can be multiplied (not dates however)

SELECT time '05:00' * 2 as time_multiplied;

------------------------------------------------- JOINING DATA FROM DIFFERENT SOURCES --------------------------------------------------------------------

-- different source systems can record dates and times in different formats
-- internal clock of the servers may be slightly off as well
-- standardizing dates and timestamps can be a challenge before analyzing
-- to prevent some events from being excluded, rather than filtering for action timestamps greater than the treatment group timestamp, 
-- allow events within a short interval window of time prior to the treatment timestamp 
-- does the timestamp recorded represent when the action that happened on the device or when the event arrived in the database?

--------------------------------------------------------- TRENDING THE DATA ------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------- SIMPLE TRENDS --------------------------------------------------------------------------------

-- common task of time series analysis is looking for trends in data
-- direction the data is moving
-- amount of noise shown in the trend over time

SELECT 
    sales_month,
    sales
FROM retail_sales
WHERE kind_of_business = 'Retail and food services sales, total';

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    date_part('year',sales_month::DATE) sales_year,
    SUM(sales) as sales
FROM retail_sales
WHERE kind_of_business = 'Retail and food services sales, total'
GROUP BY 1
ORDER BY 1;

-- graphing time series data at different levels of aggregation (weekly, monthly, yearly) is a good way to understand trends

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- multiple slices or compenents of a total across a time range, comparing these slices reveals patterns

SELECT
    date_part('year',sales_month) as sales_year,
    kind_of_business,
    SUM(sales) as sales
FROM retail_sales
WHERE kind_of_business IN ('Book stores','Sporting goods stores','Hobby, toy, and game stores')
GROUP BY 1,2
ORDER BY 1,2;

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- when our names contain an apostrophe, escape it this way

SELECT
    sales_month,
    kind_of_business,
    sales
FROM retail_sales
WHERE kind_of_business in ('Men''s clothing stores', 'Women''s clothing stores');

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- choosing to aggregate on year rather than month eliminates noise in the graph

SELECT 
    date_part('year', sales_month) AS sales_year,
    kind_of_business,
    SUM(sales) AS sales
FROM retail_sales
WHERE kind_of_business in ('Men''s clothing stores', 'Women''s clothing stores')
GROUP BY 1,2;

------------------------------------------------------- COMPARING COMPONENTS -----------------------------------------------------------------------------

-- calculating the gap between the two categories, the ratio, and the percent difference between them
-- choose which depending on the version of the story you would like to tell

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- pivot the data so theres a single row for each year with a column for each category
-- case statement works for pivoting

SELECT 
    date_part('year',sales_month::date) as sales_year,
    SUM(CASE WHEN kind_of_business = 'Women''s clothing stores' THEN sales END) as women_sales,
    SUM(CASE WHEN kind_of_business = 'Men''s clothing stores' THEN sales END) as men_sales
FROM retail_sales
WHERE kind_of_business IN ('Men''s clothing stores', 'Women''s clothing stores')
GROUP BY 1
ORDER BY 1;

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- difference

SELECT 
    sales_year,
    women_sales - men_sales AS women_minus_men
FROM
        (SELECT 
            date_part('year',sales_month::date) as sales_year,
            SUM(CASE WHEN kind_of_business = 'Women''s clothing stores' THEN sales END) as women_sales,
            SUM(CASE WHEN kind_of_business = 'Men''s clothing stores' THEN sales END) as men_sales
        FROM retail_sales
        WHERE kind_of_business IN ('Men''s clothing stores', 'Women''s clothing stores')
        GROUP BY 1
        ORDER BY 1) a;
        
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- or get the same results with a case statement rather than a subquery

SELECT
    date_part('year',sales_month::date) as sales_year,
    SUM(CASE WHEN kind_of_business = 'Women''s clothing stores' THEN sales END) - 
    SUM(CASE WHEN kind_of_business = 'Men''s clothing stores' THEN sales END) AS women_minus_men
FROM retail_sales
WHERE kind_of_business IN ('Men''s clothing stores', 'Women''s clothing stores')
GROUP BY 1
ORDER BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- ratio

SELECT 
    sales_year,
    women_sales / men_sales AS women_times_men
FROM
        (SELECT 
            date_part('year',sales_month::date) as sales_year,
            SUM(CASE WHEN kind_of_business = 'Women''s clothing stores' THEN sales END) as women_sales,
            SUM(CASE WHEN kind_of_business = 'Men''s clothing stores' THEN sales END) as men_sales
        FROM retail_sales
        WHERE kind_of_business IN ('Men''s clothing stores', 'Women''s clothing stores')
        GROUP BY 1
        ORDER BY 1) a;
        
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- percent difference

SELECT 
    sales_year,
    (women_sales / men_sales) AS women_pct_of_men
FROM
        (SELECT 
            date_part('year',sales_month::date) as sales_year,
            SUM(CASE WHEN kind_of_business = 'Women''s clothing stores' THEN sales END) as women_sales,
            SUM(CASE WHEN kind_of_business = 'Men''s clothing stores' THEN sales END) as men_sales
        FROM retail_sales
        WHERE kind_of_business IN ('Men''s clothing stores', 'Women''s clothing stores')
        GROUP BY 1
        ORDER BY 1) a;
        
-------------------------------------------------- PERCENT OF TOTAL CALCULATIONS -------------------------------------------------------------------------

-- we'll need to calculate the overall total in order to calculate percentage of total for each row
-- this can be done with a self-JOIN or window function 
-- you can join a table to itself as long as you've given it a different alias

SELECT
    sales_month,
    kind_of_business,
    sales,
    sales * 100 / total_sales AS pct_total_sales
FROM 
(
        SELECT 
            a.sales_month,
            a.kind_of_business,
            a.sales,
            SUM(b.sales) AS total_sales
        FROM retail_sales AS a
        JOIN retail_sales AS b
            ON a.sales_month = b.sales_month
            AND b.kind_of_business IN ('Men''s clothing stores', 'Women''s clothing stores')
        WHERE a.kind_of_business IN ('Men''s clothing stores', 'Women''s clothing stores')
        GROUP BY 1,2,3
        ORDER BY 1,2,3
) aa;

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- same results different method: sum window function and partition by sales_month

SELECT 
    sales_month,
    kind_of_business,
    sales,
    SUM(sales) OVER (PARTITION BY sales_month) AS total_sales,
    sales * 100 / SUM(sales) OVER (PARTITION BY sales_month) AS pct_total
FROM retail_sales
WHERE kind_of_business IN ('Men''s clothing stores', 'Women''s clothing stores');

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- percent of sales total within a longer time period (either by self-join or window function)

SELECT
    sales_month,
    kind_of_business,
    sales * 100 / yearly_sales AS pct_yearly
FROM (
        SELECT
            a.sales_month,
            b.kind_of_business,
            a.sales,
            SUM(b.sales) AS yearly_sales
        FROM retail_sales a
        JOIN retail_sales b
        ON date_part('year',a.sales_month) = date_part('year',b.sales_month)
        AND a.kind_of_business = b.kind_of_business
        AND b.kind_of_business IN ('Men''s clothing stores', 'Women''s clothing stores')
        GROUP BY 1,2,3
        ORDER BY 1,2,3
     ) a;

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT 
    sales_month,
    kind_of_business,
    sales,
    SUM(sales) OVER (PARTITION BY date_part('year',sales_month), kind_of_business) AS yearly_sales,
    sales * 100 / SUM(sales) OVER (PARTITION BY date_part('year',sales_month), kind_of_business) AS pct_yearly
FROM retail_sales
WHERE kind_of_business IN ('Men''s clothing stores', 'Women''s clothing stores')
ORDER BY 1,2;

--------------------------------------------- INDEXING TO SEE PERCENT CHANGE OVER TIME -------------------------------------------------------------------

-- indexing is a way to understand the change in a time series relative to a base period (starting point)
-- pick a base period and compute the percent change in value from that base period for each subsequent period
-- all calculations are made off the the base period rather than period before it
-- use combination of aggregation and self-joins or window functions
-- step 1: aggregate the sales by sales_year data in a subquery
-- step 2: in the outer query, the first_value window function finds the value associated with the first row
-- we're not partitioning by anything in the table, just ordering off of sales_year

SELECT 
    sales_year,
    sales,
    first_value(sales) over(order by sales_year) as index_sales
FROM
(
        SELECT
            date_part('year',sales_month) as sales_year,
            SUM(sales) as sales
        FROM retail_sales
        WHERE kind_of_business = 'Women''s clothing stores'
        GROUP BY 1
        ORDER BY 1
) a;

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- find the percent change from this base year to each row
-- why do we minus one though?

SELECT 
    sales_year,
    sales,
    first_value(sales) over(order by sales_year),
    (sales / first_value(sales) over(order by sales_year)-1) *100 as pct_from_index
FROM
(
        SELECT
            date_part('year',sales_month) as sales_year,
            SUM(sales) as sales
        FROM retail_sales
        WHERE kind_of_business = 'Women''s clothing stores'
        GROUP BY 1
) a;

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- by simply order by desc instead of asc we can change our index year to the last value
-- so everything is based off 2020

SELECT 
    sales_year,
    sales,
    (sales / first_value(sales) over(order by sales_year DESC)-1) * 100 as pct_from_index
FROM
(
        SELECT
            date_part('year',sales_month) as sales_year,
            SUM(sales) as sales
        FROM retail_sales
        WHERE kind_of_business = 'Women''s clothing stores'
        GROUP BY 1
) a;

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- self join method
-- joining on 1 = 1, we can fool the database by using any expression that evaluates true in order to create a cartesian join

SELECT
    sales_year,
    sales,
    (sales / index_sales - 1) * 100 AS pct_from_index
FROM 
        (SELECT 
            date_part('year',aa.sales_month) AS sales_year,
            bb.index_sales,
            SUM(aa.sales) as sales
         FROM retail_sales aa
         JOIN
                (SELECT 
                    first_year,
                    SUM(a.sales) AS index_sales
                 FROM retail_sales a
                 JOIN
                        (SELECT 
                            MIN(date_part('year',sales_month)) AS first_year
                         FROM retail_sales
                         WHERE kind_of_business = 'Women''s clothing stores') b 
                 ON date_part('year', a.sales_month) = b.first_year
                 WHERE a.kind_of_business = 'Women''s clothing stores'
                 GROUP BY 1) bb 
          ON 1 = 1
          WHERE aa.kind_of_business = 'Women''s clothing stores'
          GROUP BY 1,2) aaa
ORDER BY 1;

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- indexed time series for men's and women's clothes

SELECT
    sales_year,
    kind_of_business,
    sales,
    (sales / FIRST_VALUE(sales) OVER (PARTITION BY kind_of_business ORDER BY sales_year)-1) * 100 AS pct_from_index
FROM (
        SELECT
            date_part('year',sales_month) as sales_year,
            kind_of_business, 
            SUM(sales) as sales
        FROM retail_sales
        WHERE kind_of_business IN ('Men''s clothing stores', 'Women''s clothing stores')
        AND sales_month <= '2019-12-31'
        GROUP BY 1,2) a;
        
------------------------------------------------------- ROLLING TIME WINDOWS -----------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- rolling time windows takes into account multiple periods
-- moving averages are the most common but you can use any aggregate function
-- common calculations: last twelve month (LTM) aka trailing twelve months (TTM), year-to-date (YTD)
-- moving minimums and maximums can help in understanding the extremes of the data
-- choosing the partitioning or grouping of data that is in the window

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- window of 12 months to get rolling annual sales
-- table a is our anchor table from which we will gather our dates
-- table b gathers the twelve months of sales that go into the moving averages

SELECT 
    a.sales,
    a.sales_month,
    b.sales,
    b.sales_month AS rolling_sales_month
FROM retail_sales a
JOIN retail_sales b
    ON a.kind_of_business = b.kind_of_business
    AND b.sales_month BETWEEN a.sales_month - INTERVAL '11 months' AND a.sales_month
    AND b.kind_of_business = 'Women''s clothing stores'
WHERE a.kind_of_business = 'Women''s clothing stores'
    AND a.sales_month = '2019-12-01';
    
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- next we apply the aggregation (avg)

SELECT 
    a.sales_month,
    a.sales,
    AVG(b.sales) AS moving_avg,
    COUNT(b.sales_month) AS record_count
FROM retail_sales a
JOIN retail_sales b
    ON a.kind_of_business = b.kind_of_business
    AND b.sales_month BETWEEN a.sales_month - INTERVAL '11 months' AND a.sales_month
    AND b.kind_of_business = 'Women''s clothing stores'
WHERE a.kind_of_business = 'Women''s clothing stores'
    AND a.sales_month >= '1993-01-01'
GROUP BY 1,2
ORDER BY 1;

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- frame clause allows you to specify which records to include in the window function
-- by default all the records in the partition are included, however you can control the inclusion of records
-- {RANGE | ROWS | GROUPS} BETWEEN frame_start AND frame_end
-- this allows us to tackle complex calculations with relatively simple syntax

-- preceeding: include rows before the current row (according to order by sorting)
-- following: include rows after the current row
-- unbounded: means include all rows before and after the current row (for all records in the partion)
-- offset: the number of records, you can type in an integer
-- frame_exclusion: optional

-- for moving_avg, the window function is taking the sales of a month along with the 11 months before it
-- those 12 month sales numbers are averaged together
-- each row down does the same operation


SELECT
    sales_month,
    AVG(sales) OVER (ORDER BY sales_month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS moving_avg,
    COUNT(sales) OVER (ORDER BY sales_month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS records_count
FROM retail_sales
WHERE kind_of_business = 'Women''s clothing stores';

------------------------------------------------ ROLLING TIME WINDOWS WITH SPARSE DATA -------------------------------------------------------------------

-- the problem with the previous rolling window method is that it won't pick up 12 month windows of time if there's no data in that time
-- this is the case with both the self-join or window function method
-- date dimension is a static table that contains a row for every calander date
-- very useful for joins

-- moving averages stay constant until a new data point is added
-- for every date value, there are two corresponding dates (the previous sales of jan and july)

SELECT
    a.date,
    b.sales_month,
    b.sales
FROM date_dim a
JOIN 
        (SELECT 
            sales_month,
            sales
        FROM retail_sales
        WHERE kind_of_business = 'Women''s clothing stores'
        AND date_part('month',sales_month) IN (1,7)) b 
ON b.sales_month BETWEEN a.date - INTERVAL '11 months' AND a.date
WHERE a.date = a.first_day_of_month
AND a.date BETWEEN '1993-01-01' AND '2020-12-01';

----------------------------------------------------------------------------------------------------------------------------------------------------------


SELECT 
    a.date,
    -- AVG(b.sales) AS moving_avg,
    -- COUNT(b.sales) AS records
    MAX(CASE WHEN b.sales_month = a.date THEN b.sales END) AS sales_in_month
FROM date_dim a
JOIN

        (SELECT sales_month, sales
        FROM retail_sales
        WHERE kind_of_business = 'Women''s clothing stores'
        AND date_part('month',sales_month) IN (1,7)) b
ON b.sales_month BETWEEN a.date - INTERVAL '11 months' AND a.date
WHERE a.date = a.first_day_of_month
AND a.date BETWEEN '1993-01-01' AND '2020-12-31'
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT a.sales_month, AVG(b.sales) AS moving_avg
FROM 
        (SELECT DISTINCT sales_month
         FROM retail_sales
         WHERE sales_month BETWEEN '2013-01-01' AND '2020-12-01') a
JOIN retail_sales b
ON b.sales_month BETWEEN a.sales_month - INTERVAL '11 months' AND a.sales_month -- this is the way to say b.sales_month and a.sales_month are equal
AND b.kind_of_business = 'Women''s clothing stores'
GROUP BY 1
ORDER BY 1

----------------------------------------------------CALCULATING CUMULATIVE VALUES-------------------------------------------------------------------------

-- cumulative values like quarter-to-date (YTD) and month-to-date (MTD)
-- rely on a common starting point with the window size growing each row

-- this query returns a record for each sales month, the sales that month, and the accumulated sales of all months in that year


SELECT 
    sales_month,
    sales,
    SUM(sales) OVER(PARTITION BY DATE_PART('year',sales_month) ORDER BY sales_month) AS sales_ytd
FROM retail_sales
WHERE kind_of_business = 'Women''s clothing stores'

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- same results with a self-join
-- this query before aggregating shows a bit more of whats going on

SELECT
    a.sales_month,
    a.sales,
    b.sales AS b_sales
    -- SUM(b.sales) AS sales_ytd
FROM retail_sales a
JOIN retail_sales b
ON date_part('year',a.sales_month) = date_part('year',b.sales_month)
AND b.sales_month <= a.sales_month
AND b.kind_of_business = 'Women''s clothing stores'
WHERE a.kind_of_business = 'Women''s clothing stores'
-- GROUP BY 1,2

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    a.sales_month,
    a.sales,
    SUM(b.sales) AS sales_ytd
FROM retail_sales a
JOIN retail_sales b
ON date_part('year',a.sales_month) = date_part('year',b.sales_month)
AND b.sales_month <= a.sales_month
AND b.kind_of_business = 'Women''s clothing stores'
WHERE a.kind_of_business = 'Women''s clothing stores'
GROUP BY 1,2

----------------------------------------------------- ANALYZING WITH SEASONALITY -------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- seasonality can be predicted
-- seasonality can exist at other time scales like years down to minutes
-- day of week, time of day is common analysis
-- aggregating a different levels can reveal different patterns and insights
-- one way to deal with seasonality is to smooth it out using less granular time period or rolling windows

--------------------------------------------------- PERIOD OVER PERIOD COMPARISONS -----------------------------------------------------------------------

-- year-over-year, month-over-month, day-over-day
-- lag function returns a previous or lagging value from a series
-- optional offset to indicate how many rows back in the partition to take the return value (default is 1)
-- if no partition is specified it'll look back at the whole data set
-- without an order by you're not giving the database anything to work with
-- lag can essentially be turned into lead by ordering DESC

SELECT
    kind_of_business, 
    sales_month, 
    sales,
    LAG(sales_month) OVER (PARTITION BY kind_of_business ORDER BY sales_month) AS prev_month,
    LAG(sales) OVER (PARTITION BY kind_of_business ORDER BY sales_month) AS prev_month_sales
FROM retail_sales
WHERE kind_of_business = 'Book stores'

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    kind_of_business, 
    sales_month, 
    sales,
    (sales / LAG(sales) OVER (PARTITION BY kind_of_business ORDER BY sales_month) -1)  * 100 AS pct_growth_from_previous
FROM retail_sales
WHERE kind_of_business = 'Book stores'

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    kind_of_business, sales_month, sales,
    LEAD(sales_month,2) OVER(PARTITION BY kind_of_business ORDER BY sales_month)
FROM retail_sales
WHERE kind_of_business = 'Book stores'

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    kind_of_business,
    sales_month,
    sales,
    ROUND((sales / LAG(sales) OVER(PARTITION BY kind_of_business ORDER BY sales_month) - 1)*100,2) AS pct_growth_from_previous
FROM retail_sales
WHERE kind_of_business = 'Book stores'

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- calculation of YoY is similar but we need to aggregate sales on a yearly level first
-- subquery with each year and sum of sales for each year
-- the outerquery will have year, sales that year, sales previous year, percent growth from previous year

SELECT
    sales_year,
    yearly_sales,
    lag(yearly_sales) over (order by sales_year) AS previous_year,
    ROUND((yearly_sales / lag(yearly_sales) over (order by sales_year)-1)*100,2) AS perc_growth_from_prev_year
FROM 
        (SELECT
            date_part('years',sales_month) as sales_year,
            sum(sales) as yearly_sales
        FROM retail_sales
        WHERE kind_of_business = 'Book stores'
        GROUP BY 1
        ORDER BY 1) a
        
----------------------------------------------------- SAME MONTH VS LAST MONTH ---------------------------------------------------------------------------

-- controlling seasonality can be accomplished by comparing data in one time period to data in a previous similar time period
-- like comparing values of the same month from the previous year

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- the date part returns an integer not a date type

SELECT
    sales_month,
    date_part('month',sales_month)
FROM retail_sales
WHERE kind_of_business = 'Book stores'

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- using date_part in the partition so the window function can look up the value for matching month number from previous year
-- good idea to check intermediate results and build intuition

SELECT
    sales_month,
    sales,
    LAG(sales_month) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month) AS prev_year_month,
    LAG(sales) OVER (PARTITION BY date_part('month', sales_month) ORDER BY sales_month)
FROM retail_sales
WHERE kind_of_business = 'Book stores'

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- calculating absolute difference

SELECT
    sales_month,
    sales,
    sales - LAG(sales) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month),
    ROUND((sales / LAG(sales) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month) -1) * 100,2) AS pct_diff
FROM retail_sales
WHERE kind_of_business = 'Book stores'

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- how to pivot your data using date_part and to_char along with aggregate functions

SELECT
    date_part('month',sales_month) AS month_number,
    to_char(sales_month,'Month') AS month_name,
    MAX(CASE WHEN date_part('year',sales_month) = 1992 THEN sales END) AS sales_1992,
    MAX(CASE WHEN date_part('year',sales_month) = 1993 THEN sales END) AS sales_1993,
    MAX(CASE WHEN date_part('year',sales_month) = 1994 THEN sales END) AS sales_1994   
FROM retail_sales
WHERE kind_of_business = 'Book stores'
AND sales_month BETWEEN '1992-01-01' AND '1994-12-01'
GROUP BY 1,2

-- before aggregating max
-- seeing this tells you you use use max becuase there's only one value to return when you group by month_number and month_name

SELECT 
    date_part('month',sales_month),
    to_char(sales_month,'Month'),
    CASE WHEN date_part('year',sales_month) = 1992 THEN sales END AS sales_1992,
    CASE WHEN date_part('year',sales_month) = 1993 THEN sales END AS sales_1993,
    CASE WHEN date_part('year',sales_month) = 1994 THEN sales END AS sales_1994

------------------------------------------------ COMPARING TO MULTIPLE PRIOR PERIODS ---------------------------------------------------------------------

-- this method can reduce the noise that arises from seasonality
-- rather than comparing a single month of a year to a single month of previous year
-- comparing one monday to another monday that happens to be a holiday will not be insightful

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- using the offset value in the lag function to create multiple previous values of a particular time

SELECT
    sales_month,
    sales,
    LAG(sales,1) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month) as prev_sales_1,
    LAG(sales, 2) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month) as prev_sales_2,
    LAG(sales, 3) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month) as prev_sales_3
FROM retail_sales
WHERE kind_of_business = 'Book stores'
GROUP BY 1,2

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- calculates the percent of the rolling average of three prior periods 

SELECT
    sales_month,
    sales,
    (sales / ((prev_sales_1 + prev_sales_2 + prev_sales_3) / 3)) * 100 AS pct_of_3_prev
FROM
        (SELECT
            sales_month,
            sales,
            LAG(sales,1) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month) as prev_sales_1,
            LAG(sales, 2) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month) as prev_sales_2,
            LAG(sales, 3) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month) as prev_sales_3
         FROM retail_sales
         WHERE kind_of_business = 'Book stores') a;
         
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- window function method that returns the same results 
-- rather than making a column for each of the 3 previous sales months

SELECT
    sales_month,
    sales,
    (sales / 
    AVG(sales) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING))*100 AS pct_of_3_prev
FROM retail_sales
WHERE kind_of_business = 'Book stores'


-- this breaks down the previous query
-- what we get from our avg window function is the same as averaging the 3 prev_sales columns

SELECT
    sales_month,
    sales,
    LAG(sales,1) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month) as prev_sales_1,
    LAG(sales, 2) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month) as prev_sales_2,
    LAG(sales, 3) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month) as prev_sales_3,
    AVG(sales) OVER (PARTITION BY date_part('month', sales_month) ORDER BY sales_month ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING)
FROM retail_sales
WHERE kind_of_business = 'Book stores'
ORDER BY date_part('month', sales_month)
----------------------------------------------------------------------------------------------------------------------------------------------------------
