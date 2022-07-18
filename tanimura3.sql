---------------------------------------------------------------------------------------------------------------------------------------------------------
-- many databases are set to UTC the global standard, its the most common but certainly not universal
-- the one drawback to UTC is that we lose information about the local time humans do actions 

SELECT '2020-09-01 00:00:00 -0' at time zone 'pst'; -- changing from UTC to PST

------------------------------------------------------ FORMAT CONVERSION --------------------------------------------------------------------------------

SELECT current_date;
SELECT localtimestamp;
SELECT now();

SELECT current_time;
SELECT localtime;
SELECT timeofday();

-- DATE_TRUNC -> function to reduce the granularity of a timestamp, similar to DATE_FORMAT in mysql

SELECT date_trunc('year', '2020-10-04 12:33:35' :: timestamp);
SELECT date_trunc('month', '2020-10-04 12:33:35' :: timestamp);
SELECT date_trunc('day', '2020-10-04 12:33:35' :: timestamp);

-- DATE_PART -> returns a text value for the part to be returned of a date/timestamp

SELECT date_part('day',current_timestamp);
SELECT date_part('month',current_timestamp);
SELECT date_part('year',current_timestamp);
SELECT date_part('quarter',current_timestamp);
SELECT date_part('week',current_timestamp);
SELECT date_part('hour',current_timestamp);
SELECT date_part('minute',current_timestamp);

-- using DATE_PART and EXTRACT with INTERVAL (your interval must match with the request part)

SELECT date_part('day',INTERVAL '30 days');
SELECT extract('day' FROM INTERVAL '30 days');

-- TO CHAR -> to return text values of the date parts

SELECT to_char(current_timestamp, 'Day');
SELECT to_char(current_timestamp, 'Month');

-- concatenating two timestamps together

SELECT date '2020-09-01' + time '03:00:00' as timestamp;

-- assembling dates 

SELECT make_date(2020,09,01);
SELECT to_date(CONCAT(2020,'-',09,'-',01),'yyyy-mm-dd');
SELECT cast(concat(2020,'-',09,'-',01) as date);

-------------------------------------------------- DATE MATH -------------------------------------------------------------------------------------------

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

------------------ TIME MATH ------------------

-- whenever the elapsed time between two events is less than a day, or rounding to number of days doesn't provide enough information, time manipulation comes into play

SELECT time '05:00' + interval '3 hours' as new_time;
SELECT time '05:00' - interval '3 hours' as new_time;
SELECT time '05:00' - time '03:00' as new_time;

-- times can be multiplied (not dates however)
SELECT time '05:00' * 2 as time_multiplied;

------------------------------------------------- JOINING DATA FROM DIFFERENT SOURCES -------------------------------------------------------------------

-- different source systems can record dates and times in different formats
-- internal clock of the servers may be slightly off as well
-- standardizing dates and timestamps can be a challenge before analyzing
-- to prevent some events from being excluded, rather than filtering for action timestamps greater than the treatment group timestamp, allow events within a short interval window of time prior to the treatment timestamp 
-- does the timestamp recorded represent when the action that happened on the device or when the event arrived in the database?

------------------------------------------------------ TRENDING THE DATA --------------------------------------------------------------------------------

SELECT 
    sales_month,
    sales
FROM retail_sales
WHERE kind_of_business = 'Retail and food services sales, total';
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    date_part('year',sales_month::DATE) sales_year,
    SUM(sales) as sales
FROM retail_sales
WHERE kind_of_business = 'Retail and food services sales, total'
GROUP BY 1
ORDER BY 1;
-- graphing time series data at different levels of aggregation (weekly, monthly, yearly) is a good way to understand trends
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    date_part('year',sales_month) as sales_year,
    kind_of_business,
    SUM(sales) as sales
FROM retail_sales
WHERE kind_of_business IN ('Book stores','Sporting goods stores','Hobby, toy, and game stores')
GROUP BY 1,2
ORDER BY 1,2
---------------------------------------------------------------------------------------------------------------------------------------------------------
-- when our names contain an apostrophe, escape it this way
WHERE kind_of_business in ('Men''s clothing stores', 'Women''s clothing stores')
---------------------------------------------------------------------------------------------------------------------------------------------------------
-- calculating the gap between the two categories, the ratio, and the percent difference between them
-- choose which depending on the version of the story you would like to tell
---------------------------------------------------------------------------------------------------------------------------------------------------------
-- pivot the data so theres a single row for each year with a column for each category
SELECT 
    date_part('year',sales_month::date) as sales_year,
    SUM(CASE WHEN kind_of_business = 'Women''s clothing stores' THEN sales END) as women_sales,
    SUM(CASE WHEN kind_of_business = 'Men''s clothing stores' THEN sales END) as men_sales
FROM retail_sales
WHERE kind_of_business IN ('Men''s clothing stores', 'Women''s clothing stores')
GROUP BY 1
ORDER BY 1;
---------------------------------------------------------------------------------------------------------------------------------------------------------
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
---------------------------------------------------------------------------------------------------------------------------------------------------------
-- or get the same results with a case statement rather than a subquery
SELECT
    date_part('year',sales_month::date) as sales_year,
    SUM(CASE WHEN kind_of_business = 'Women''s clothing stores' THEN sales END) - SUM(CASE WHEN kind_of_business = 'Men''s clothing stores' THEN sales END) AS women_minus_men
FROM retail_sales
WHERE kind_of_business IN ('Men''s clothing stores', 'Women''s clothing stores')
GROUP BY 1
ORDER BY 1
---------------------------------------------------------------------------------------------------------------------------------------------------------
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
---------------------------------------------------------------------------------------------------------------------------------------------------------
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
---------------------------------------------------------------------------------------------------------------------------------------------------------
-- percent of total calculation
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
---------------------------------------------------------------------------------------------------------------------------------------------------------
-- same results different method: sum window function and partition by sales_month
SELECT 
    sales_month,
    kind_of_business,
    sales,
    SUM(sales) OVER (PARTITION BY sales_month) AS total_sales,
    sales * 100 / SUM(sales) OVER (PARTITION BY sales_month) AS pct_total
FROM retail_sales
WHERE kind_of_business IN ('Men''s clothing stores', 'Women''s clothing stores');
---------------------------------------------------------------------------------------------------------------------------------------------------------
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
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT 
    sales_month,
    kind_of_business,
    sales,
    SUM(sales) OVER (PARTITION BY date_part('year',sales_month), kind_of_business) AS yearly_sales,
    sales * 100 / SUM(sales) OVER (PARTITION BY date_part('year',sales_month), kind_of_business) AS pct_yearly
FROM retail_sales
WHERE kind_of_business IN ('Men''s clothing stores', 'Women''s clothing stores')
ORDER BY 1,2;
------------------------------------------------- INDEXING TO SEE PERCENT CHANGE OVER TIME --------------------------------------------------------------
-- indexing is a way to understand the change in a time series relative to a base period (starting point)
-- pick a base period and compute the percent change in value from that base period for each subsequent period
-- use combination of aggregation and self-joins or window functions
-- step 1: aggregate the sales by sales_year data in a subquery
-- step 2: in the outer query the first_value window function finds the value associated with the first row in the partition by clause, but use order by 
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
---------------------------------------------------------------------------------------------------------------------------------------------------------
-- find the percent change from this base year to each row
SELECT 
    sales_year,
    sales,
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
---------------------------------------------------------------------------------------------------------------------------------------------------------
-- by simply order by desc instead of asc we can change our index year to the last value
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
---------------------------------------------------------------------------------------------------------------------------------------------------------
-- self join method
SELECT
    sales_year,
    sales,
    (sales / index_sales - 1) * 100 AS pct_from_index
FROM 
(
    SELECT 
        date_part('year',aa.sales_month) AS sales_year,
        bb.index_sales,
        SUM(aa.sales) as sales
    FROM retail_sales aa
    JOIN
    (
        SELECT 
            first_year,
            SUM(a.sales) AS index_sales
        FROM retail_sales a
        JOIN
        (
            SELECT 
                MIN(date_part('year',sales_month)) AS first_year
            FROM retail_sales
            WHERE kind_of_business = 'Women''s clothing stores'
        ) b ON date_part('year', a.sales_month) = b.first_year
        WHERE a.kind_of_business = 'Women''s clothing stores'
        GROUP BY 1
     ) bb ON 1 = 1
     WHERE aa.kind_of_business = 'Women''s clothing stores'
     GROUP BY 1,2
 ) aaa
 ORDER BY 1
 ;
---------------------------------------------------------------------------------------------------------------------------------------------------------
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
------------------ ROLLING TIME WINDOWS ------------------
-- rolling time windows takes into account multiple periods
-- moving averages are the most common but you can use any aggregate function
-- common calculations: last twelve month (LTM) aka trailing twelve months (TTM), year-to-date (YTD)
-- moving minimums and maximums can help in understanding the extremes of the data
-- choosing the partitioning or grouping of data that is in the window
---------------------------------------------------------------------------------------------------------------------------------------------------------
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
---------------------------------------------------------------------------------------------------------------------------------------------------------
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
---------------------------------------------------------------------------------------------------------------------------------------------------------
-- frame clause allows you to specify which records to include in the window function
-- by default all the records in the partition are included, however you can control the inclusion of records
-- {RANGE | ROWS | GROUPS} BETWEEN frame_start AND frame_end

SELECT
    sales_month,
    AVG(sales) OVER (ORDER BY sales_month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS moving_avg,
    COUNT(sales) OVER (ORDER BY sales_month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS records_count
FROM retail_sales
WHERE kind_of_business = 'Women''s clothing stores'
---------------------------------------------------------------------------------------------------------------------------------------------------------
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
AND a.date BETWEEN '1993-01-01' AND '20202-12-01'
;
---------------------------------------------------------------------------------------------------------------------------------------------------------
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
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT a.sales_month, AVG(b.sales) AS moving_avg
FROM 
        (SELECT DISTINCT sales_month
         FROM retail_sales
         WHERE sales_month BETWEEN '2013-01-01' AND '2020-12-01') a
JOIN retail_sales b
ON b.sales_month BETWEEN a.sales_month - INTERVAL '11 months' AND a.sales_month -- this is the way to say b.sales_month and a.sales_month are equal to each other
AND b.kind_of_business = 'Women''s clothing stores'
GROUP BY 1
ORDER BY 1
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT a.sales_month, AVG(b.sales) AS moving_avg
FROM 
        (SELECT DISTINCT sales_month
         FROM retail_sales
         WHERE sales_month BETWEEN '2013-01-01' AND '2020-12-01') a
JOIN retail_sales b
ON b.sales_month BETWEEN a.sales_month - INTERVAL '11 months' AND a.sales_month -- this is the way to say b.sales_month and a.sales_month are equal to each other
AND b.kind_of_business = 'Women''s clothing stores'
GROUP BY 1
ORDER BY 1
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT 
    sales_month,
    sales,
    SUM(sales) OVER(PARTITION BY DATE_PART('year',sales_month) ORDER BY sales_month) AS sales_ytd
FROM retail_sales
WHERE kind_of_business = 'Women''s clothing stores'
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    a.sales_month,
    a.sales,
    SUM(b.sales) AS sales_ytd
FROM retail_sales a
JOIN retail_sales b
ON date_part('year',a.sales_month) = date_part('year',b.sales_month)
AND b.sales_month <= a.sales_month -- why???
AND b.kind_of_business = 'Women''s clothing stores'
WHERE a.kind_of_business = 'Women''s clothing stores'
GROUP BY 1,2
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    kind_of_business, sales_month, sales,
    LAG(sales_month) OVER(PARTITION BY kind_of_business ORDER BY sales_month)
FROM retail_sales
WHERE kind_of_business = 'Book stores'
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    kind_of_business, sales_month, sales,
    LAG(sales_month) OVER(PARTITION BY kind_of_business ORDER BY sales_month DESC)
FROM retail_sales
WHERE kind_of_business = 'Book stores'
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    kind_of_business, sales_month, sales,
    LEAD(sales_month,2) OVER(PARTITION BY kind_of_business ORDER BY sales_month)
FROM retail_sales
WHERE kind_of_business = 'Book stores'
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    kind_of_business,
    sales_month,
    sales,
    ROUND((sales / LAG(sales) OVER(PARTITION BY kind_of_business ORDER BY sales_month) - 1)*100,2) AS pct_growth_from_previous
FROM retail_sales
WHERE kind_of_business = 'Book stores'
---------------------------------------------------------------------------------------------------------------------------------------------------------
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
---------------------------------------------------------------------------------------------------------------------------------------------------------
-- the date part returns an integer not a date type
SELECT
    sales_month,
    date_part('month',sales_month)
FROM retail_sales
WHERE kind_of_business = 'Book stores'
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    sales_month,
    sales,
    LAG(sales_month) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month) AS prev_year_month,
    LAG(sales) OVER (PARTITION BY date_part('month', sales_month) ORDER BY sales_month)
FROM retail_sales
WHERE kind_of_business = 'Book stores'
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    sales_month,
    sales,
    sales - LAG(sales) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month),
    ROUND((sales / LAG(sales) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month) -1) * 100,2) AS pct_diff
FROM retail_sales
WHERE kind_of_business = 'Book stores'
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    date_part('month',sales_month),
    to_char(sales_month,'Month'),
    MAX(CASE WHEN date_part('year',sales_month) = 1992 THEN sales END) AS sales_1992,
    MAX(CASE WHEN date_part('year',sales_month) = 1993 THEN sales END) AS sales_1993,
    MAX(CASE WHEN date_part('year',sales_month) = 1994 THEN sales END) AS sales_1994   
FROM retail_sales
WHERE kind_of_business = 'Book stores'
AND sales_month BETWEEN '1992-01-01' AND '1994-12-01'
GROUP BY 1,2
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    sales_month,
    sales,
    LAG(sales,1) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month) as prev_sales_1,
    LAG(sales, 2) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month) as prev_sales_2,
    LAG(sales, 3) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month) as prev_sales_3
FROM retail_sales
WHERE kind_of_business = 'Book stores'
GROUP BY 1,2
---------------------------------------------------------------------------------------------------------------------------------------------------------
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
---------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    sales_month,
    sales,
    (sales / 
    AVG(sales) OVER (PARTITION BY date_part('month',sales_month) ORDER BY sales_month ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING))*100 AS pct_of_3_prev
FROM retail_sales
WHERE kind_of_business = 'Book stores'

