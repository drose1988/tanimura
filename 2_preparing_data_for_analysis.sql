----------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------- Preparing Data for Analysis ---------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- data dictionaries are essential for data preparation
-- they are a document or repository with clear descriptions of the fields, possible values, how data was collected, how it relates to other data
-- improves your analysis because you can verify you have used fields correctly
-- additionally data preparation work involves profiling the data and data shaping techniques

------------------------------------------------------------- Types of Data ------------------------------------------------------------------------------

-- you don't necessarily have to be an expert on all the nuances of data types
-- but knowing about data types is essential for deciding how to analyze data appropriately, which is why profiling is important
-- when data is loaded, if strings are too big for the defined data type, they could be truncated or rejected entirely

-- numeric data can be positive or negative, mathematical functions can be applied, ex INT :: FLOAT :: DOUBLE :: DECIMAL
-- boolean (true/false) is often used to create flags that summarize the presence of absense of a property in the data

------------------------------------------------------ Structured vs. Unstructured -----------------------------------------------------------------------

-- most databases were designed to handle structured data
-- when structured data is inserted into a table, each field is verified to ensure it conforms to the correct data type
-- unstructured data is "everything else" that is not considered database data
-- unstructured data has no predetermined structure, data model, or data type
-- it is often stored outside of relational databases 
-- this allows data to be loaded quickly but lacks data validation resulting in low quality data

------------------------------------------------------- 1st 2nd 3rd Party Data ---------------------------------------------------------------------------

-- first party data is collected by the organization itself
-- collected through server logs or other systems that are built in-house to generate data of interest

-- second party data comes from vendors
-- the code that generates and stores the data is not controlled by the organization, analysts have little influence over this

-- third party data is purchased or obtained from free sources 
-- little control over data quality
-- lacks the granularity compared to 1st and 2nd party data

-- sparce data is when majority of the entries show up as nulls with few values in a column
-- JSON is an approach to handle sparce entries, stores only the data present and omits the rest

----------------------------------------------------- Don't kill your database ---------------------------------------------------------------------------

-- take advantage of LIMIT when building queries, you can go through the steps with a LIMIT but when you're actually looking for final results take it off
-- MOD function returns the remainder when one integer is divided by another
-- you can use this function for sampling of your records
-- this returns the last two digit values of user_id, which is about 1% of the total user_ids

SELECT user_id, MOD(user_id,100) FROM game_users
SELECT DISTINCT MOD(user_id,1000) FROM game_users -- this brings back a sample of 100  

-------------------------------------------------- Profiling: distributions ------------------------------------------------------------------------------

-- profiling should be the first thing you do when working on a new data set
-- construct a mental model of how the tables relate to one another
-- review a data dictionary if it exists
-- what domains are covered or represented in a table
-- how is history represented, are previous values represented

-- after profiling, start looking at how data is distributed
-- how often values occur, value ranges, if nulls/ null frequency, negative values?

-- frequency queries are a great way to detect sparce data
-- frequency checks can be done with any data type
-- graph with histograms
-- you can create histograms with other aggregations like min max sum avg 

-- simple GROUP BY to check frequency

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT fruit, COUNT(*) AS quanity
FROM fruit_quantity
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT age, COUNT(customer_id) AS customers
FROM customers
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- an aggregation followed by a frequency count (intermediate aggregation step)
-- orders table with fields: date, customer_id, order_id, amount
-- write a query that returns distributions of orders per customer

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT 
    orders,
    COUNT(*) AS num_customers
FROM
        (SELECT customer_id, COUNT(order_id) AS orders
         FROM orders
         GROUP BY 1) a
GROUP BY 1

------------------------------------------------------------------- Binning ------------------------------------------------------------------------------

-- binning is useful for working with continuous values
-- bins can vary in size or have a fixed size depending on your goal
-- roughly equal bin width or roughly equal number of records?
-- case statements are flixible way to control number of bins 
-- if you have very long tail of values, case statements are useful if you want to put all those scarce long tail values into one bin
-- rather than having a bunch of empty bins in your distribution
-- fixed-size bins or arbitrary-size bins

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    CASE WHEN order_amount <= 100 THEN 'up to 100'
         WHEN order_amount <= 500 THEN '100 to 500'
         ELSE '500+' END AS amount_bin, 
    CASE WHEN order_amount <= 100 THEN 'small'
         WHEN order_amount <= 500 THEN 'medium'
         ELSE 'large' END AS amount_category,
    COUNT(DISTINCT customer_id) AS customers
FROM orders
GROUP BY 1, 2

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- rounding, logarithms, n-tiles can create fixed-size bins

-- ROUND: use -1, -2, -3 etc with round to create limit the bin size 
-- for example ROUND(amount, -3) returning amounts 147000, 123000, 161000.., now you have more controlled bin sizes

SELECT 
    ROUND(sales, -1) AS bin,
    COUNT(customer_id) AS customers
FROM table
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- LOG: useful if the largest values are magnitude greater than the smallest values (as in several decimal places larger)
-- log(1) = 0 :::: log(10) = 1 :::: log(100) = 2 :::: log(1000) = 3
-- doesn't work if values are less than or equal to 0, will return an error likely

SELECT
    LOG(sales) AS bin,
    COUNT(customer_id) AS customers
FROM table
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- n-tile function is a window function 
-- same concept as quartiles, deciles, but you specify the number of bins

SELECT * ,
  ntile(10) OVER (ORDER BY sales) as ntiles
FROM retail_sales
WHERE sales IS NOT NULL
ORDER BY sales_month

-- we can find the lower and upper boundaries for each ntile by doing this
-- and specifically how many orders have fallen into each ntile (should be about the same)

SELECT
    ntiles,
    MIN(sales) as lower_bound,
    MAX(sales) as upper_bound,
    COUNT(*) as orders
FROM
        (SELECT * ,
          ntile(10) OVER (ORDER BY sales) as ntiles
        FROM retail_sales
        WHERE sales IS NOT NULL
        ORDER BY sales_month) a
GROUP BY 1
ORDER BY 1 

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- similarly percent_rank() returns the percentile
-- can be used for creating continuous distributions
-- these functions can be taxing on the server however

---------------------------------------------------------------Window Functions --------------------------------------------------------------------------

-- aka analytic functions
-- window functions perform calculations that span multiple rows 
-- ORDER BY clause determines the rows on which to operate and the ordering of the rows
-- PARTITION BY clause doesn't require a field but when field(s) are specified the function will only operate on that section of rows

-- aggregation: SUM, COUNT, MAX, MIN, AVG
-- value: LAG, LEAD, FIRST_VALUE, LAST_VALUE, NTH_VALUE
-- ranking: ROW_NUMBER, RANK, DENSE_RANK, CUME_DIST, PERCENT_RANK, NTILE


------------------------------------------------------------ Profiling: data quality ---------------------------------------------------------------------

-- garbage in garbage out
-- profiling is a way of uncovering data quality issues early on, before it negatively impact results and conclusions
-- uncover gaps and changes in the data

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- detecting duplicates
-- easiest way to detect duplicates
-- if a record has the same exact values in all columns as another record, then the new aggregate records column we create should catch it
-- you want this to return a zero
-- duplicate data, or data that contains multiple records per entity even though they're not duplicates
-- one of the most common reasons for incorrect query results

SELECT COUNT(*)
FROM
    (SELECT sales_month, naics_code, kind_of_business, reason_for_null, sales, COUNT(*) AS records FROM retail_sales
    GROUP BY 1,2,3,4,5) a
WHERE records > 1

-- if there are duplicates you can run this to list out the number of records that are duplicates

SELECT records, COUNT(*)
FROM
    (SELECT sales_month, naics_code, kind_of_business, reason_for_null, sales, COUNT(*) AS records FROM retail_sales
    GROUP BY 1,2,3,4,5) a
WHERE records > 1
GROUP BY 1

------------------------------------------------------ Preparing: cleaning data --------------------------------------------------------------------------

---- case statements for cleaning ------------------------------------------------------------------------------------------------------------------------

-- method for standardizing values into specific categories
-- data inputed can have slighly different values even if they are meant to represent the same thing
-- ex female, F, femme, woman 
-- adding meaningful categorization that doesn't exist in the original data

---- flagging with case statements -----------------------------------------------------------------------------------------------------------------------

-- create a flag to indicate whether a certain value is present or not (aka dummy variable)
-- if the data set has multiple rows per entity you can flatten the data with max aggregation and group by
---- type convertion and casting ----
-- sometimes we need to overwrite a data type and force it to be something else
-- CAST(1234 AS VARCHAR)
-- 1234 :: VARCHAR

CASE WHEN order_items <=3 THEN order_items :: VARCHAR
     ELSE '4+'
     END

-- we need to cast the order_items because we can't mix text and numeric data in a case column 

-- sometimes databases automatically convert data type (type coercion)
-- like FLOAT can be mixed with INT and CHAR can be mixed with VARCHAR
-- but some require you to convert fileds to the same type

---- Nulls with coalesce, nullif, nvl functions ----

CASE WHEN num_orders IS NULL THEN 0 ELSE num_orders END
CASE WHEN address IS NULL THEN 'unknown' ELSE address END
CASE WHEN column_a IS NULL THEN column_b ELSE column_a END

-- or

COALESCE(num_orders,0)
COALESCE(address,'unknown')
COALESCE(column_a,column_b,column_c)

---- missing data ----------------------------------------------------------------------------------------------------------------------------------------

-- we can detect missing data by comparing values in two tables
-- checking to make sure all customer_ids in the transactions table exist in the customers table

SELECT DISTINCT a.customer_id
FROM transaction a
LEFT JOIN customers b ON a.customer_id = b.customer_id
WHERE b.customer_id IS NULL

-- we could use a derived value column in replace of a column with missing data

SELECT gross_sales - discount AS net_sales

-- missing values could be filled with values from other rows in the data set
-- like the value from the previous record or next record

LAG(product_price) OVER(PARTITION BY product ORDER BY order_date)
LEAD(product_price) OVER(PARTITION BY product ORDER BY order_date)

-- generate_series function can be used to create a date dimension
-- generate_series(start,stop,step interval)
-- useful for when we want have a record for every date even if there isn't a record for a purchase for every date  

SELECT generate_series :: date
FROM generate_series('2001-01-01' :: date,'2030-12-31', '1 day')

SELECT a.generate_series AS order_date, b.customer_id, b.items
FROM 
    (SELECT *
     FROM generate_series('2001-01-01' :: date,'2030-12-31', '1 day')) a
 
LEFT JOIN 
    (SELECT customer_id, order_date, COUNT(item_id) AS items
     FROM orders
     GROUP BY 1,2) b
ON a.generate_series = b.order_date

------------------------------------------------------- Preparing: shaping data --------------------------------------------------------------------------

-- shaping data refers to manipulating the way data is represented in columns and rows
-- figure out the granularity of the data that you need 
-- flatten the data (reduce the number of rows that represent an entity)
-- pivoting and unpivoting

---- for which output ------------------------------------------------------------------------------------------------------------------------------------

-- what are you planning to do with the data afterwards
-- BI tool for reporting and dashboarding
-- spreadsheets for business users
-- R for statistical tools
-- python for machine learning
-- think about the level of aggregation the end user will need to filter on
-- think "tidy data": each variable forms a column, each observation forms a row, each value forms a cell

---- pivoting with CASE statements -----------------------------------------------------------------------------------------------------------------------

-- pivoting is a good way of summarize data for business audiences
-- reshaping it into more compact easy to digest form
-- at the intersection of each column and row is an aggregate function
-- pivoting doesn't work well when new values are constantly arriving and are rapidly changing
-- better when there is a finite number of items to pivot 


SELECT order_date,
    SUM(CASE WHEN product = 'shirt' THEN order_amount ELSE 0 END) AS shirts_amount,
    SUM(CASE WHEN product = 'shoes' THEN order_amount ELSE 0 END) AS shoes_amount,
    SUM(CASE WHEN product = 'hat' THEN order_amount ELSE 0 END) AS hat_amount
FROM orders
GROUP BY 1


SELECT sales_month,
    SUM(CASE WHEN kind_of_business = 'Warehouse clubs and superstores' THEN sales ELSE 0 END) AS warehouse_amount,
    SUM(CASE WHEN kind_of_business = 'Automobile dealers' THEN sales ELSE 0 END) AS auto_amount,
    SUM(CASE WHEN kind_of_business = 'Other general merchandise stores' THEN sales ELSE 0 END) AS other_amount
FROM retail_sales
GROUP BY 1
ORDER BY 1

SELECT *
FROM retail_sales
    pivot(SUM(sales) FOR kind_of_business in ('Warehouse clubs and superstores','Automobile dealers','Other general merchandise stores'))
GROUP BY sales_month

-- this actually doesn't work

---- unpivoting with UNION statements --------------------------------------------------------------------------------------------------------------------

-- moving data in pivot table back into tidy data
-- using UNION or UNION ALL the numbers of columns in each part of the query must match, along with the data types (with some mixing allowed)
-- UNION removes duplicates while UNION ALL retains all records
-- can be used to bring together data from differnet sources
----------------------------------------------------------------------------------------------------------------------------------------------------------
