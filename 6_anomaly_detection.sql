----------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------- Anomaly Detection ----------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- anomaly is something that is different from other members of the group
-- aka outliers, novelties, noise, deviations, exceptions
-- anomalys can be a result of real events or errors from data collection/input
-- important to distinguish between these two types of anomalys for analysis
-- deciding what to do with anomalys requires domain knowledge of the data
-- anomalys produced by errors in data processing can be more confidently corrected or discarded 
-- anomalys aren't always necessarily a problem, detecting anomalys can give important insight
-- sql doesn't have the statistical sophistication of R or python

----------------------------------------------------------- Detecting Outliers ---------------------------------------------------------------------------

-- challenges are: knowing when a value or data point is common or rare, setting a threshold for marking values rare
-- sometimes there is a "ground truth" about what the range these values should be in that we can reference
-- other times its up to you to make a reasonable judgement call


SELECT * 
FROM earthquakes 
WHERE mag IS NOT NULL 
ORDER BY mag DESC 
LIMIT 1000

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- to find the percent of all earthquakes of a particular magnitude
-- the window function is used to determine total number of earthquakes
-- we have to use a partition even though we don't want to, so using 1 forces sql to make the window function
-- the rest is straightforward, *100 to make it a percent

SELECT
    mag,
    COUNT(id) AS earthquakes,
    ROUND(COUNT(id),8) * 100,
    SUM(COUNT(id)) OVER (PARTITION BY 1),
    ROUND(COUNT(id),8) * 100 / SUM(COUNT(id)) OVER (PARTITION BY 1) AS pct_earthquakes
FROM earthquakes
WHERE mag IS NOT NULL 
GROUP BY 1
ORDER BY 1 DESC

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- given the frequency of -9.99 and -9, and how much bigger the value is than the next lowest, you can deduce that they represent an unknown value

SELECT
    mag,
    COUNT(id) AS earthquakes,
    ROUND(COUNT(id),8) * 100 / SUM(COUNT(id)) OVER (PARTITION BY 1) AS pct_earthquakes
FROM earthquakes
WHERE mag IS NOT NULL 
GROUP BY 1
ORDER BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    place,
    mag,
    COUNT(*)
FROM earthquakes
WHERE mag IS NOT NULL
  AND place = 'Northern California'
GROUP BY 1,2
ORDER BY 1,2 DESC

-------------------------------------- Calculating Percentiles and Standard Deviations to Find Anomalies--------------------------------------------------

-- rather than simply detecting, we quantify the extremes using percentiles and standard deviations
-- median() is commonly used in most dbs
-- a percentile represents the percentage of value in a distribution that are less than a particular value

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- percent_rank doesn't take any argument, it requires the over clause but not partiton by or order by, it operates over all rows returned by the query
-- if there are 500 total earthquakes labeled 'Northern California' and 300 of them are less than mag 0.55 then the percentile of mag 0.55 would be 0.6

SELECT
    place,
    mag,
    percentile,
    COUNT(*)
FROM
        (SELECT
            place,
            mag,
            PERCENT_RANK() OVER(PARTITION BY place ORDER BY mag) AS percentile
        FROM earthquakes
        WHERE mag IS NOT NULL 
          AND place = 'Northern California') a
GROUP BY 1,2,3
ORDER BY 2 DESC
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- there are 100 values of ntile here, each of those 100 have about 334 records
-- using ntiles is like dividing all the records into a specified number of bins
-- and the mag value determines what bin the record falls into

SELECT
    place,
    mag,
    NTILE(100) OVER (PARTITION BY place ORDER BY mag) as ntile
FROM earthquakes
WHERE mag IS NOT NULL
  AND place = 'Central Alaska'
ORDER BY 2 DESC

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- to figure out what the boundaries of our ntiles are, we use max and min 

SELECT
    place,
    ntile,
    MAX(mag) AS min,
    MIN(mag) AS max
FROM
        (SELECT
            place,
            mag,
            NTILE(4) OVER (PARTITION BY place ORDER BY mag) as ntile
        FROM earthquakes
        WHERE mag IS NOT NULL
          AND place = 'Central Alaska'
        ORDER BY 2 DESC) a
GROUP BY 1,2
ORDER BY 2 DESC

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- percentile_cont: returns an interpolated(calculated) value that corresponds to the exact percentile but may not exist in the data set
-- percentile_disc: returns the value in the data set that is closest to the requested percentile
-- for larger data sets there is unlikely any different in the values returned

SELECT
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY mag) AS pct_25,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY mag) AS pct_50,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY mag) AS pct_75
FROM earthquakes
WHERE mag IS NOT NULL AND place = 'Central Alaska'

SELECT
    PERCENTILE_DISC(0.25) WITHIN GROUP (ORDER BY mag) AS pct_25,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY mag) AS pct_50,
    PERCENTILE_DISC(0.75) WITHIN GROUP (ORDER BY mag) AS pct_75
FROM earthquakes
WHERE mag IS NOT NULL AND place = 'Central Alaska'

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- percentiles of different fields can be calculated in the same query by specifying the field in the order by

SELECT
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY mag) AS mag_25,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY depth) AS depth_25
FROM earthquakes
WHERE mag IS NOT NULL AND place = 'Central Alaska'

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- when multiple fields are present in the query using a percentile_cont, you need a group by 

SELECT
    place,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY mag) AS mag_25,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY depth) AS depth_25
FROM earthquakes
WHERE mag IS NOT NULL AND place IN ('Central Alaska','Southern Alaska')
GROUP BY 1


----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    STDDEV_POP(mag) AS stddev_pop_mag,
    STDDEV_SAMP(mag) AS stddev_samp_mag
FROM earthquakes

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- stddev_pop for the sd of a population
-- stddev_samp for the sd of a sample (calculates N - 1)
-- stddev function in other dbs is identical the stddev_pop
-- this is applying the z score formula, a simple subquery to return avg and stddev for the data set
-- then use those values with each observation to get z score
-- join the tables on 1 = 1

SELECT 
    a.place,
    a.mag,
    b.avg_mag,
    b.stddev_mag,
    (a.mag - b.avg_mag) / b.stddev_mag AS z_score_mag
    
FROM earthquakes a 
JOIN 
        (SELECT
            AVG(mag) AS avg_mag,
            STDDEV_POP(mag) AS stddev_mag
        FROM earthquakes
        WHERE mag IS NOT NULL) b
  ON 1 = 1
WHERE a.mag IS NOT NULL
ORDER BY 2 DESC

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- returns box plot information
-- the value range of the upper and lower whisker are typically 1.5 times the interquartile range
-- for example the median magnitude here is 4.5 and values 4.3 - 4.7 makeup 50% of the distribution (the middle 25% to 75%)
-- but we take the difference of 75% percentile and 25% percentile and multiply by 1.5 to get our interquartile range

SELECT 
    ntile25,
    median,
    ntile75,
    (ntile75 - ntile25) * 1.5 AS iqr,
    ntile25 - (ntile75 - ntile25) * 1.5 AS lower_whisker,
    ntile75 + (ntile75 - ntile25) * 1.5 AS upper_whisker    
FROM
        (SELECT
            PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY mag) AS ntile25,
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY mag) AS median,
            PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY mag) AS ntile75
        FROM earthquakes
        WHERE mag IS NOT NULL AND place LIKE '%Japan%') a
        
----------------------------------------------------------------------------------------------------------------------------------------------------------
-- box plots can be compared across groupings of the data
-- here we are grouping on year
-- if you just group by everything in the outer query you can get all your box plot information for each year grouping

SELECT
    yr,
    ntile25,
    median,
    ntile75,
    (ntile75 - ntile25) * 1.5 AS iqr,
    ntile25 - (ntile75 - ntile25) * 1.5 AS lower_whisker,
    ntile75 + (ntile75 - ntile25) * 1.5 AS upper_whisker
FROM
        (SELECT
            DATE_PART('year',time) :: INT AS yr,
            PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY mag) AS ntile25,
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY mag) AS median,
            PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY mag) AS ntile75
        FROM earthquakes
        WHERE mag IS NOT NULL AND place LIKE '%Japan%'
        GROUP BY 1) a
GROUP BY 1,2,3,4,5,6,7

--------------------------------------------------------- Forms of Anomalys ------------------------------------------------------------------------------

-- anomalies can we in the form of values, counts/frequencies, presence/absence

--------------------------------------------------------- Anomalous Values -------------------------------------------------------------------------------

-- first thing that comes to mind for anomalous values is extreme highs or lows, when the middle values are otherwise unusual
-- here we see the varying number of digits for all our values
-- we likely want to round the values to the same number of significant digits

SELECT
    mag,
    COUNT(*)
FROM earthquakes
WHERE mag > 1
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------


SELECT 
    net,
    COUNT(*)
FROM earthquakes
WHERE depth > 600
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT 
    place,
    COUNT(*)
FROM earthquakes
WHERE depth > 600
GROUP BY 1
ORDER BY 2 DESC

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- texting parcing makes summary information more accurate
-- for example two place values can have different values but represent the same thing

SELECT
    CASE WHEN place LIKE '% of %' THEN SPLIT_PART(place,' of ',2) ELSE place END AS place,
    COUNT(*)
FROM earthquakes
WHERE depth > 600
GROUP BY 1
ORDER BY 2 DESC

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- cleaning the data of misspellings, capitalizations, text errors, etc is essential
-- misspellings can be difficult to correct, use a CASE statement
-- the goal is to flag the cases
-- also join to a table with just the correct values if possible

SELECT
    COUNT(DISTINCT type) AS distict_types,
    COUNT(DISTINCT LOWER(type)) AS lower_distinct_types
FROM earthquakes

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- creating a boolean flag field to tell us when the type value is different from the type value lowercased
-- then find the specific records where this is the case

SELECT *
FROM
        (SELECT
            type,
            LOWER(type),
            type = LOWER(type) AS flag,
            COUNT(*) AS records
        FROM earthquakes
        GROUP BY 1,2,3
        ORDER BY 2,4 DESC) a
WHERE flag = 'false'


----------------------------------------------- Anomalous Counts of Frequencies --------------------------------------------------------------------------

-- anomalies aren't always a matter of individual values
-- anomalous activity can be in the form of patterns or clusters in the data
-- for example events that happen with unusual frequency over a short period of time
-- can be good or bad
-- our goal is to detect these types of anomalies, when there is a deviation from the normal trend
-- use time series and aggregation together
-- we aim to understand normal patterns and look for unusual ones
-- finding anomalous counts, sums, frequencies usually involves query at different levels of granularity
-- start braod then go more granular, then zoom out to compaire to baseline trends, zooming back in on specific splits or dimensions in the data

SELECT
    DATE_TRUNC('year',time) :: DATE AS earthquake_year,
    COUNT(*) AS earthquakes
FROM earthquakes
GROUP BY 1
ORDER BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    DATE_TRUNC('month',time) :: DATE AS earthquake_month,
    COUNT(*) AS earthquakes
FROM earthquakes
GROUP BY 1
ORDER BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- we can choose how granular the period of times can be seperated

SELECT
    DATE_TRUNC('month',time) :: DATE AS earthquake_month,
    status,
    COUNT(*) AS earthquakes
FROM earthquakes
GROUP BY 1,2
ORDER BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    CASE WHEN place LIKE '% of %' THEN SPLIT_PART(place,' of ',2) ELSE place END AS place,
    COUNT(*)
FROM earthquakes
WHERE mag >= 6
GROUP BY 1
ORDER BY 2 DESC

----------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------- Anomalies from the Absence of Data -----------------------------------------------------------------------

-- detecting the absence of data is difficult when you're not specifically looking for it
-- use the methods for cohort analysis with a join to date diemsnion
-- to ensure a record exists for every entity even if they were not active during a particular time
-- detecting gaps in time is a way of detecting absence of data (time last seen)

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- starting with the first subquery
-- when theres a comma, space, and capital letter, we're gonna get the broader region
-- so this narrows down the possible place values

SELECT
    REPLACE(INITCAP(
        CASE WHEN place ~ ', [A-Z]' THEN SPLIT_PART(place,' ',2)
             WHEN place ~ '% of %' THEN SPLIT_PART(place,' ',2)
             ELSE place END),
    'Region','') AS place,
    time
FROM earthquakes
WHERE mag > 5

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- each record is still an earthquake, window function to get next time of earthquake
-- along with window function for fixed latest value for every place

SELECT
    place,
    time,
    LEAD(time) OVER (PARTITION BY place ORDER BY time) AS next_time,
    LEAD(time) OVER (PARTITION BY place ORDER BY time) - time AS gap,
    MAX(time) OVER (PARTITION BY place) AS latest
FROM
        (SELECT
            REPLACE(INITCAP(
                CASE WHEN place ~ ', [A-Z]' THEN SPLIT_PART(place,' ',2)
                     WHEN place ~ '% of %' THEN SPLIT_PART(place,' ',2)
                     ELSE place END),
            'Region','') AS place,
            time
        FROM earthquakes
        WHERE mag > 5) a
ORDER BY 1,2

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- the days_since_latest is saying: take the difference of 2020-12-31 and each latest value, then get the number of days of that value
-- this isn't an aggregate though so you'll have to group by it
-- the last two extract functions in the select clause are aggregates so they're also grouped by place and days_since_latest
-- you could use current_timestamp instead of 12-31-2020 but this data ends at 2020
-- if data refreshed on an ongoing basis, it'd be better to use current_timestamp
-- when the current gap is within range of a customers historical gap values, we can judge that the customer is retained
-- but if the value is much larger we can start to think they're churned out, or at risk to churn out

SELECT
    place,
    EXTRACT('days' FROM '2020-12-31 23:59:59' - latest) AS days_since_latest,
    COUNT(*) AS earthquakes,
    EXTRACT('days' FROM AVG(gap)) AS avg_gap,
    EXTRACT('days' FROM MAX(gap)) AS max_gap
    
FROM
        (SELECT
            place,
            time,
            LEAD(time) OVER (PARTITION BY place ORDER BY time) AS next_time,
            LEAD(time) OVER (PARTITION BY place ORDER BY time) - time AS gap,
            MAX(time) OVER (PARTITION BY place) AS latest
        FROM
                (SELECT
                    REPLACE(INITCAP(
                        CASE WHEN place ~ ', [A-Z]' THEN SPLIT_PART(place,', ',2)
                             WHEN place ~ '% of %' THEN SPLIT_PART(place,', ',2)
                             ELSE place END),
                    'Region','') AS place,
                    time
                FROM earthquakes
                WHERE mag > 5) a
        ORDER BY 1,2) aa
GROUP BY 1,2
ORDER BY 1 


------------------------------------------------------ Handling Anomalies --------------------------------------------------------------------------------

-- how we handle anomalies depends on the source of the anomaly and end goal of our analysis

-------- invesigation --------

-- process of investigating anomalies involves querying to go back and forth between between searching for patterns and looking at specific examples
-- check records that share a certain attribute (from another field) and see if their values are anomalous too or something unsual going on
-- this could unearth other anomalies
-- after investigating and uncovering the source of the anomalies, get in touch with stakeholders and owners to be transparent 

----------- removal ----------

-- if there is reason to believe an error in data collection caused the anomaly then all other values in the record might be compromised, so should delete it
-- remove outliers if they skew the data to lead to to inappropriate conclusions? make sure you're not introducing bias though
-- before removing outliers check and see if removing them makes a difference in the overall analysis output

SELECT
    time,
    mag,
    type
FROM earthquakes
WHERE mag NOT IN (-9,-9.99)

----------------------------------------------------------------------------------------------------------------------------------------------------------
-- here we can see than the avg_mag isn't considerably different when we remove the erroneous values

SELECT
    AVG(mag) AS avg_mag,
    AVG(CASE WHEN mag > -9 THEN mag END) AS avg_mag_adjusted
FROM earthquakes

----------------------------------------------------------------------------------------------------------------------------------------------------------
-- however when the dataset is narrowed down on conditions, the difference in average may increase and the outliers become more apparent

SELECT
    AVG(mag) AS avg_mag,
    AVG(CASE WHEN mag > -9 THEN mag END) AS avg_mag_adjusted
FROM earthquakes
WHERE place = 'Yellowstone National Park, Wyoming'

-- replace with alt value ----

-- alternate value can be a default, substitute value, or nearest numerical value within a range, or summary statistic (avg, median)

SELECT
    CASE WHEN type = 'earthquake' THEN type ELSE 'other' END AS event_type,
    COUNT(*)
FROM earthquakes
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    PERCENTILE_CONT(.95) WITHIN GROUP (ORDER BY mag) AS percentile_95,
    PERCENTILE_CONT(.05) WITHIN GROUP (ORDER BY mag) AS percentile_05
FROM earthquakes

----------------------------------------------------------------------------------------------------------------------------------------------------------
-- winsorization: this method takes the most extreme values and replaces them with a near low/high value that is not as extreme
-- this can prevent misleading averages resulting from extreme outliers
-- in this example all the magnitude values bigger than the 95% percentile value or smaller than the 5% percentile
-- those values are replaced with whatever the 95% and 5% value are
-- there is no set percentile threshold for winsorization, depends on the situation

SELECT
    a.time,
    a.place,
    a.mag,
    CASE WHEN a.mag > b.percentile_95 THEN b.percentile_95
         WHEN a.mag < b.percentile_05 THEN b.percentile_05
         ELSE a.mag END AS mag_winsorize
FROM earthquakes a
JOIN 
        (SELECT
            PERCENTILE_CONT(.95) WITHIN GROUP (ORDER BY mag) AS percentile_95,
            PERCENTILE_CONT(.05) WITHIN GROUP (ORDER BY mag) AS percentile_05
        FROM earthquakes) b
ON 1 =1 
WHERE a.mag IS NOT NULL
ORDER BY 3 DESC

-------- rescaling --------

-- rescaling the values rather than replacing, allows us to retain all the values while still making analysis and graphing easy
-- z score method is powerful especially when you have a combination of postive and negative values that you can normalize
-- logarithmic scale transformations cannot use negative numbers
-- graphing log values on a histogram has the effect of making the x axis range less influenced by the extreme values, and the smaller values get spread out


SELECT
    ROUND(depth,1) AS depth,
    ROUND(LOG(ROUND(depth,1)),5) AS log_depth,
    COUNT(*) AS earthquakes
FROM earthquakes
WHERE depth >= 0.05
GROUP BY 1,2
ORDER BY 1 DESC

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- other commonly used scale transformations (for rescaling not removing): square root, cube root, reciprocal transformation

----------------------------------------------------------------------------------------------------------------------------------------------------------
