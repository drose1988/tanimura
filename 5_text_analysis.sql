----------------------------------------------------------------------------------------------------------------------------------------------------------

-- important note: to get around the permission denied importing a csv
        -- go to terminal and type "open /tmp" into it
        -- drag the csv into this folder
        -- then type COPY public."ufo" FROM '/private/tmp/ufo1.csv' DELIMITER ',' CSV HEADER;
        -- this worked
        
----------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------- TEXT ANALYSIS --------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- structured data: data is in different table fields with distinct meanings
-- semistructured: data is in seperate columns but may need parsing and cleaning
-- unstructured: data VARCHAR or BLOB fields hold arbitrary length strings, extensive structuring needed before analysis

-- text analysis is deriving meaning or insight from text data
-- qualitative analysis (textual analysis) 
-- quantitative analysis of text: the output is quantitative, ex. categorization and data extraction in conjunction with counts/frequencies over time

-- goals and strategies of text analysis: text extraction, categorization, sentiment analysis
-- SQL is good at some form of text analysis but for advanced tasks, other languages and tool are better

-------------------------------------------------- when SQL is good for text analysis --------------------------------------------------------------------

-- advantage of sql is that the data is already in the database
-- moving to a flat file for analysis is time consuming
-- databases are more powerful at processing and less error prone that spreadsheets
-- the original data stays intact
-- sql shines in cleaning and structuring text fields
-- structuring: creating new columns from elements extracted or derived from other fields
-- rule based system for sql code used in text analysis, though code can become very long
-- sql is good when you know in advanced what you are looking for

------------------------------------------------ when SQL is not good for text analysis ------------------------------------------------------------------

-- when the data set is small or new, hand labeling can be faster and more informative
-- sentiment analysis like analyzing ranges of positive or negative emotions, has its limitations with sql
-- and it would we nearly impossible to create a rule set with sql to handle 
-- better handled with python

----------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT * FROM ufo LIMIT 100
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- to get to know your text dataset, find number of characters in your values and see the distribution, max, avg, min
-- also maybe run through a few hundred rows of the records to get familiar with content
SELECT LENGTH(sighting_report) FROM ufo
SELECT LENGTH(description) FROM ufo

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    LENGTH(sighting_report),
    COUNT(*)
FROM ufo
GROUP BY 1
ORDER BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    AVG(LENGTH(sighting_report)) AS avg_length,
    MIN(LENGTH(sighting_report)) AS min_length,
    MAX(LENGTH(sighting_report)) AS max_length
FROM ufo

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- parsing a field into several new fields each which contain a single piece of information
        -- plan the field of desired output
        -- apply parsing functions
        -- apply transformation, like data type conversion
        -- check results to see if some don't conform
        -- repeat the steps until its right
        
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- the first 8 characters of every record in the field is 'Occurred'

SELECT 
    LEFT(sighting_report,8),
    COUNT(*)
FROM ufo
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT RIGHT(LEFT(sighting_report,25),14) AS occurred
FROM ufo

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- alternative to using right,left
-- better option becuase we look for specific sequence of characters in a string and return the left or right side of it
-- this is a delimiter, typically like a comma or dash but can also be sequence of characters
-- straightforward, 1 goes left, 2 goes right

SELECT SPLIT_PART('This is an example of an example string','an example',1)
SELECT SPLIT_PART('This is an example of an example string','an example',2)

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    SPLIT_PART(sighting_report,'Occurred : ',2)
FROM ufo

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    SPLIT_PART(sighting_report,' (Entered',1)
FROM ufo

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- the process of returning the part of the text between two delimiters, in this case the content of 'occurred'

SELECT
    SPLIT_PART(
        SPLIT_PART(sighting_report,' (Entered',1)
    ,'Occurred : ',2) AS occurred
FROM ufo

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- data from sighting_report thats been parsed into individual fields but not clean

SELECT
  SPLIT_PART(SPLIT_PART(SPLIT_PART(sighting_report,' (Entered',1),'Occurred : ',2),'Reported',1) AS occurred,  
  SPLIT_PART(SPLIT_PART(sighting_report,')Reported:',1),'(Entered as :',2) AS entered,    
  SPLIT_PART(SPLIT_PART(sighting_report,'Posted:',1),'Reported: ',2) AS reported,  
  SPLIT_PART(SPLIT_PART(sighting_report,'Location: ',1),'Posted: ',2) AS posted,  
  SPLIT_PART(SPLIT_PART(sighting_report,'Shape: ',1),'Location: ',2) AS location,  
  SPLIT_PART(SPLIT_PART(sighting_report,'Duration:',1),'Shape: ',2) AS shape,  
  SPLIT_PART(sighting_report,'Duration:',2) AS duration 
FROM ufo

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- unitcap will capitalize the first letter of the string

SELECT
    DISTINCT shape,
    INITCAP(shape) AS clean_shape
FROM 
    (SELECT
      SPLIT_PART(SPLIT_PART(SPLIT_PART(sighting_report,' (Entered',1),'Occurred : ',2),'Reported',1) AS occurred,  
      SPLIT_PART(SPLIT_PART(sighting_report,')Reported:',1),'(Entered as :',2) AS entered,    
      SPLIT_PART(SPLIT_PART(sighting_report,'Posted:',1),'Reported: ',2) AS reported,  
      SPLIT_PART(SPLIT_PART(sighting_report,'Location: ',1),'Posted: ',2) AS posted,  
      SPLIT_PART(SPLIT_PART(sighting_report,'Shape: ',1),'Location: ',2) AS location,  
      SPLIT_PART(SPLIT_PART(sighting_report,'Duration:',1),'Shape: ',2) AS shape,  
      SPLIT_PART(sighting_report,'Duration:',2) AS duration 
    FROM ufo) a
    
----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    clean_shape,
    COUNT(*)
FROM 
    (SELECT
      SPLIT_PART(SPLIT_PART(sighting_report,'Duration:',1),'Shape: ',2) AS shape,
      INITCAP(SPLIT_PART(SPLIT_PART(sighting_report,'Duration:',1),'Shape: ',2)) AS clean_shape
    FROM ufo) a
GROUP BY 1
ORDER BY 2 DESC

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- trim will remove blank spaces at the beginning and end of a string, aka white spaces

SELECT 
    duration,
    TRIM(duration) AS duration_clean
    
FROM
       (SELECT SPLIT_PART(sighting_report,'Duration:',2) AS duration 
        FROM ufo) a
        
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- doesn't work because some of the records can't be reformatted as a timestamp
-- an empty string is still a string and can't be converted to another data type

SELECT
    occurred::timestamp,
    reported::timestamp AS reported,
    posted:: date AS posted
FROM
        (SELECT
          SPLIT_PART(SPLIT_PART(SPLIT_PART(sighting_report,' (Entered',1),'Occurred : ',2),'Reported',1) AS occurred,  
          SPLIT_PART(SPLIT_PART(SPLIT_PART(SPLIT_PART(sighting_report,'Post',1),'Reported: ',2),' AM',1),' PM',1) AS reported,  
          SPLIT_PART(SPLIT_PART(sighting_report,'Location',1),'Posted: ',2) AS posted
        FROM ufo) a
        
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- when you use a case statement to make the records that are blank or have a length less than 8 NULL 
-- then you can return the good records that can be converted to a timestamp

SELECT
    CASE WHEN occurred = '' THEN NULL
         WHEN LENGTH(occurred) < 8 THEN NULL
         ELSE occurred :: timestamp
         END as occurred,
    CASE WHEN reported = '' THEN NULL 
         WHEN LENGTH(reported) < 8 THEN NULL
         ELSE reported :: timestamp
         END as reported,
    CASE WHEN posted = '' THEN NULL 
         ELSE posted :: date
         END as posted
FROM
        (SELECT
          SPLIT_PART(SPLIT_PART(SPLIT_PART(sighting_report,' (Entered',1),'Occurred : ',2),'Reported',1) AS occurred,  
          SPLIT_PART(SPLIT_PART(SPLIT_PART(SPLIT_PART(sighting_report,'Post',1),'Reported: ',2),' AM',1),' PM',1) AS reported,  
          SPLIT_PART(SPLIT_PART(sighting_report,'Location',1),'Posted: ',2) AS posted
        FROM ufo) a
        
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- replace used to change part of a string to something else or to remove the content entirely

SELECT

    location,
    REPLACE(REPLACE(location,'close to', 'near'),'outside of','near') AS location_clean
FROM
(SELECT
    SPLIT_PART(SPLIT_PART(sighting_report,'Shape: ',1),'Location: ',2) AS location
FROM ufo) a

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- start with parsing then move to cleaning each column

CREATE VIEW cleaned_sighting_report AS
SELECT
    CASE WHEN occurred = '' THEN NULL
         WHEN LENGTH(occurred) < 8 THEN NULL
         ELSE occurred :: timestamp
         END as occurred,
    CASE WHEN reported = '' THEN NULL 
         WHEN LENGTH(reported) < 8 THEN NULL
         ELSE reported :: timestamp
         END as reported,
    CASE WHEN posted = '' THEN NULL 
         ELSE posted :: date
         END as posted,
    entered_as,
    REPLACE(REPLACE(location,'close to', 'near'),'outside of','near') AS location_clean,
    INITCAP(shape) AS clean_shape,    
    TRIM(duration) AS duration_clean
    
    -- (this is just for your to play around) CASE WHEN TRIM(duration) NOT LIKE '%minutes' AND 
    -- TRIM(duration) NOT LIKE '%seconds' THEN CONCAT(TRIM(duration),' seconds') ELSE TRIM(duration) END AS duration_cleaner

----------------------------------------------------------------------------------------------------------------------------------------------------------

FROM
(SELECT
  SPLIT_PART(SPLIT_PART(SPLIT_PART(sighting_report,' (Entered',1),'Occurred : ',2),'Reported',1) AS occurred,  
  SPLIT_PART(SPLIT_PART(sighting_report,')Reported:',1),'(Entered as :',2) AS entered_as,    
  SPLIT_PART(SPLIT_PART(SPLIT_PART(SPLIT_PART(sighting_report,'Post',1),'Reported: ',2),' AM',1),' PM',1) AS reported,  
  SPLIT_PART(SPLIT_PART(sighting_report,'Location: ',1),'Posted: ',2) AS posted,  
  SPLIT_PART(SPLIT_PART(sighting_report,'Shape: ',1),'Location: ',2) AS location,  
  SPLIT_PART(SPLIT_PART(sighting_report,'Duration:',1),'Shape: ',2) AS shape,  
  SPLIT_PART(sighting_report,'Duration:',2) AS duration 
FROM ufo) a

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT COUNT(*)
FROM ufo
WHERE description LIKE '%wife%'

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT COUNT(*)
FROM ufo
WHERE LOWER(description) LIKE '%wife%'

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- not available in MySQL or SQL Server

SELECT *
FROM ufo
WHERE description ILIKE '%wife%'

----------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT COUNT(*)
FROM ufo
WHERE LOWER(description) LIKE '%wife%' OR LOWER(description) LIKE '%husband%'

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- be careful about using parenthesis to get the order of operations you want 
-- this reads: contains wife, or it contains husband and mother (if a record contains either of those options itll be returned)

SELECT COUNT(*)
FROM ufo
WHERE LOWER(description) LIKE '%wife%' OR LOWER(description) LIKE '%husband%' AND LOWER(description) LIKE '%mother%'

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    CASE WHEN LOWER(description) LIKE '%walking%' THEN 'walking'
         WHEN LOWER(description) LIKE '%driving%' THEN 'driving'
         WHEN LOWER(description) LIKE '%running%' THEN 'running'
         WHEN LOWER(description) LIKE '%cycling%' THEN 'cycling'
         WHEN LOWER(description) LIKE '%swimming%' THEN 'swimming'
         ELSE 'none' END AS activity,
    COUNT(*)
FROM ufo
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- this type of conditional logic works to generate a column of boolean logic, like case statement or where clause
-- think of it like a case statement but just for true/false bins
-- useful to use with counts or sums
-- ilike is a case insensitive like operator, not available in every db

SELECT
    description,
    description ILIKE 'north' AS north,
    description ILIKE 'south' AS south,
    description ILIKE 'east' AS east,
    description ILIKE 'west' AS west,
    LENGTH(description) > 500 AS over_500
FROM ufo

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    description ILIKE '%north%' AS north,
    description ILIKE '%south%' AS south,
    description ILIKE '%east%' AS east,
    description ILIKE '%west%' AS west,
    COUNT(description)
FROM ufo
GROUP BY 1,2,3,4
ORDER BY 5 DESC

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- this is already flattened so each record is unique
-- meaning if a description contains north and south a 1 will show up for the north and south fields
-- that way you can just count them without grouping by anthing 

SELECT
    COUNT(CASE WHEN description ILIKE '%north%' THEN 1 END) AS north,
    COUNT(CASE WHEN description ILIKE '%south%' THEN 1 END) AS south,
    COUNT(CASE WHEN description ILIKE '%east%' THEN 1 END) AS east,
    COUNT(CASE WHEN description ILIKE '%west%' THEN 1 END) AS west
FROM ufo

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    first_word,
    description
        FROM 
        (SELECT
            SPLIT_PART(description,' ',1) AS first_word,
            description
        FROM ufo) a
WHERE first_word IN ('Red','Blue','Green','Yellow','Purple','White','Orange')

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- you have to use lower with in because like and in don't work together

SELECT
    CASE WHEN LOWER(first_word) IN ('red','blue','green','yellow','purple','white','orange') THEN 'Color'
         WHEN LOWER(first_word) IN ('round','circular','oval','cigar') THEN 'Shape'
         WHEN first_word ILIKE 'triang%' THEN 'Shape'
         WHEN first_word ILIKE 'flash%' THEN 'Motion'
         WHEN first_word ILIKE 'hover%' THEN 'Motion'
         WHEN first_word ILIKE 'pulsat%' THEN 'Motion'
         Else 'Other' END AS first_word_type,
    COUNT(*)
FROM 
        (SELECT
            SPLIT_PART(description,' ',1) AS first_word,
            description
        FROM ufo) a
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------- Regular Expressions -----------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- regular expressions (regex) is a powerful method for finding and matching patterns in sql
-- all major dbs have some implementation of rejex but its different syntax
-- regex is a lanugage that used within other languages
-- regex is sql: either with POSIX comparators or regex functions

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- tilde symbol ~ compares two statements and returns true if one statement is contained in the other

SELECT 'This data is about UFOs' ~ 'data' AS comparison -- true
SELECT 'This data is about UFOs' ~ 'DATA' AS comparison -- false, case sensitive
SELECT 'This data is about UFOs' ~* 'DATA' AS comparison -- true, case insensitive
SELECT 'This data is about UFOs' !~ 'alligators' AS comparison -- true

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    'This data is about UFOs' ~ '. data' AS comparison1, -- the period is asking if there is a single character before ' data'
    'This data is about UFOs' ~ '.The' AS comapison2 -- the period is asking if there is a single character before 'The' in the statement
    
----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    'This data is about UFOs' ~ 'data *' AS comparison1, -- the asterisk is asking if there are zero or more characters after 'data ' 
    'This data is about UFOs' ~ 'data %' AS comapison2 -- the asterisk is like a % wildcard but in regular functions the % is evaluated as that character
    
----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT 'The data is about UFOs' ~ '[Tt]he' AS comparison -- this asks: is there a 'The' or 'the' in the statement

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    'The data is about UFOs' ~ '[Tt]he' AS comparison1,
    'the data is about UFOs' ~ '[Tt]he' AS comparison2,
    'tHe data is about UFOs' ~ '[Tt]he' AS comparison3,
    'THE data is about UFOs' ~ '[Tt]he' AS comparison4,
    'THE data is about UFOs' ~* '[Tt]he' AS comparison5
    
----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT 'sighting lasted 8 minutes' ~ '[789] minutes' AS comparison -- asks: is there a 7,8,or 9 coming before ' minutes'

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    'sighting lasted 8 minutes' ~ '[0123456789] minutes' AS comparison1, -- instead of typing this
    'sighting lasted 8 minutes' ~ '[0-9] minutes' AS comparison2 -- type this
    
----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT 'That costed me $8' ~ '[$%#&]' AS comparison -- nonnumber and nonletter values can be placed between brackets

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT 
    'I took 280 to get to work' ~ '[0-9][0-9][0-9]' AS comparison1, -- is asking for 3 consecutive numbers
    'I took 28 minutes to get to work instead of 1 hour' ~ '[0-9][0-9][0-9]' AS comparison2, -- still false because its asking consecutive
    'I took 28 minutes to get to work instead of 1 hour' ~ '[0-9][0-9]*[0-9]' AS comparison3 -- now its true 
    
----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    'The data is about UFOs' ~ '[a-z]he' AS comparison1, -- matches any lowercase letter before 'he'
    'the data is about UFOs' ~ '[A-Z]he' AS comparison2, -- matches any uppercase letter before 'he'
    'tHe data is about UFOs' ~ '[A-Za-z0-9]he' AS comparison3, -- matches any uppercase letter, lowercase letter or number before 'he'
    'THE data is about UFOs' ~ '[A-z]he' AS comparison4 -- matches any ASCII character, not that useful
    
----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    'driving on 495 south' ~ 'on [0-9+]' AS comparison1, -- asks is there 'on ' followed by a number one time or multiple times 
    'driving on 1 south' ~ 'on [0-9+]' AS comparison2,
    'driving on 38east' ~ 'on [0-9+]' AS comparison3,
    'driving on route one' ~ 'on [0-9+]' AS comparison4
    
 ----------------------------------------------------------------------------------------------------------------------------------------------------------   
 
SELECT
    'driving on 495 south' ~ 'on [0-9+]' AS comparison1, 
    'driving on 495 south' ~ 'on ^[0-9+]' AS comparison2, -- asks is there 'on ' thats not followed by a number
    'driving on 495 south' ~ '^on [0-9+]' AS comparison3 -- asks does this text not have 'on ' followed by a number in it
    
----------------------------------------------------------------------------------------------------------------------------------------------------------  

SELECT 
    'a' ~ 'a+', -- is there 'a' followed by something else one or more times
    'aa' ~ 'a+',
    'aaa' ~ 'a+',
    'bbb' ~ 'a+'
    
---------------------------------------------------------------------------------------------------------------------------------------------------------- 

SELECT
    'abc' ~ 'ab?c', -- is there 'a' followed by 'b' one or zero times followed by 'c'
    'ac' ~ 'ab?c', -- true because this there is zero 'b' before 'a' and 'c'
    'abbc' ~ 'ab?c' -- false because there are two 'b' between 'a' and 'c'
    
SELECT
    'abc' ~ 'ab*c', -- true: is there an 'a' followed by a 'b' zero or more times followed by a 'c'
    'ac' ~ 'ab*c', -- true theres zero 'b' between 'a' and 'c'
    'abb' ~ 'ab*c' -- false theres no 'c' which we've required

SELECT
    'a' ~ 'a{3}', -- is there exactly three occurances of 'a' in the string
    'aa' ~ 'a{3}',
    'aaaa' ~ 'a{3}',
    'aaaaa' ~ 'a{3}',
    'a man ran' ~ 'a{3}' -- still false because the three 'a' need to be consecutive
    
----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    '"Is there a report?" she asked' ~ '\?' as comparison1, 
            -- since we are tryping to match '?' which in regex is a special character, we put a backslash before it to evaluate it as a match
    'it was filed under ^51' ~ '^[0-9]+' as comparison2, 
            -- no backslash in the expression so its not evaluating '^' in the text its still a special character
    'it was filed under ^51' ~ '\^[0-9]+' as comparison2 
            -- now its evaluating '^' in the text

-- '\t' looks for a tab
-- '\s' looks for any whitespace character including a space
-- '\r' looks for newlines with carriage return
-- '\n' looks for newlines with line feed
-- carriage return points the cursor to the beginning of the line horizontally and line feed shifts the cursor to the next line vertically
-- so use '\r\n'

----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    'valid codes have the form 12a34b56c' ~ '([0-9]{2}[a-z]){3}', 
            -- asks is there two consecutive numbers followed by a lowercase letter, and is does that combination happen 3 consecutive times
    'the first code entered was 123a456c' ~ '([0-9]{2}[a-z]){3}' 
            -- the combination is not happening, the parenthesis are the factor
    
----------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT
    'I was in my car going south toward my home' ~ 'car' AS comparison1,
    'UFO scares cows and starts stampede breaking' ~ 'car' AS comparison2,
    'I''m a carpenter and married father of 2 kids' ~ 'car' AS comparison3,
    'It looked like a brown boxcar way up in the sky' ~ 'car' AS comparison4
    
----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
    'I was in my car going south toward my home' ~ '\ycar\y' AS comparison1, 
            -- true: asks is there 'car' in the text and is there a space before and after 'car'
    'UFO scares cows and starts stampede breaking' ~ '\ycar\y' AS comparison2, 
            -- false because there no space before and after car
    'I''m a carpenter and married father of 2 kids' ~ '\ycar\y' AS comparison3,
    'It looked like a brown boxcar way up in the sky' ~ '\ycar\y' AS comparison4, 
            -- false theres a space after but not before
    'Cars don''t need to start behaving like humans' ~* '\ycars\y' AS comparison5, 
            -- true: because '\y' before 'cars' will pick the cases when 'cars' is at the start of the sentence too
    'Cars don''t need to start behaving like humans' ~* ' cars ' AS comparison5 
            -- false, see this is the difference between '\y' and ' '
    
----------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT 
    'Car lights in the sky passing over the highway' ~* '\Acar\y' AS comaparison1, -- starts with 'car' case insensitive and has space after
    'I was in my car going south toward my home' ~* '\Acar\y' AS comaparison2, -- doesn't start with car 
    'A object is sighted hovering in place over my car' ~* '\ycar\Z' AS comaparison3, -- has a space in front of 'car' and ends on 'car'
    'I was in the car going south towards my home' ~* '\ycar\Z' AS comaparison4 -- not the case here
    
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- in the first 50 characters of description
-- what records have a number (one more multiple times) followed by a space and 'light'(with either s space comma period after)

SELECT left(description,50)
FROM ufo
WHERE left(description,50) ~ '[0-9]+ light[s ,.]'

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- regexp_matches: like the POSIX but instead of returning a true false, yyou can return the part of the string that matches the pattern 
-- you can see on the return here why the plus after the numbers is needed to return not just a single digit number if its multi digit

SELECT 
    (regexp_matches(description,'[0-9]+ light[s ,.]'))[1],
    COUNT(*)
FROM ufo
WHERE description ~ '[0-9]+ light[s ,.]'
GROUP BY 1
ORDER BY 2 desc

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- of that last query with a count of each matched text
-- find the space and go left of it, of those values with is the min and max

SELECT 
    MIN(SPLIT_PART(matched_text,' ',1)::int) as min_lights,
    MAX(SPLIT_PART(matched_text,' ',1)::int) as max_lights
FROM
        (SELECT 
            (regexp_matches(description,'[0-9]+ light[s ,.]'))[1] as matched_text,
            COUNT(*)
        FROM ufo
        WHERE description ~ '[0-9]+ light[s ,.]'
        GROUP BY 1) a
        
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- regexp_replace: to replace the matched text with some alternative text
-- particularly useful when multiple spellings for the same thing are present

SELECT 
    SPLIT_PART(sighting_report,'Duration:',2) as duration,
    COUNT(*) as reports
FROM ufo
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- this counts all the different duration texts
-- and the regexp_matches takes duration and
-- looks for a pattern in duration that starts with m, followed by 'min' case insensitive, some other text zero or more times, and a space at the end
-- and it returns this as in a new column

SELECT 
    duration,
    (regexp_matches(duration,'\m[Mm][Ii][Nn][A-Za-z]*\y'))[1] as matched_minutes
FROM
        (SELECT 
            SPLIT_PART(sighting_report,'Duration:',2) as duration,
         COUNT(*) as reports
         FROM ufo
         GROUP BY 1) a
        
---------------------------------------------------------------------------------------------------------------------------------------------------------- 

-- this shows the duraction text, the matching text extracted out of it, and the duration text with the replacement text

SELECT 
    duration,
    (regexp_matches(duration,'\m[Mm][Ii][Nn][A-Za-z]*\y'))[1] as matched_minutes,
    regexp_replace(duration,'\m[Mm][Ii][Nn][A-Za-z]*\y','min') as replaced_text
FROM
        (SELECT split_part(sighting_report,'Duration:',2) as duration
        ,count(*) as reports
        FROM ufo
        GROUP BY 1) a
        
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- regexp_replace can be nested inside itself many times

SELECT 
    duration,
    (regexp_matches(duration,'\m[Hh][Oo][Uu][Rr][A-Za-z]*\y'))[1] as matched_hour,
    (regexp_matches(duration,'\m[Mm][Ii][Nn][A-Za-z]*\y'))[1] as matched_minutes,
    regexp_replace(regexp_replace(duration,'\m[Mm][Ii][Nn][A-Za-z]*\y','min'),'\m[Hh][Oo][Uu][Rr][A-Za-z]*\y','hr') as replaced_text
FROM
        (SELECT 
            SPLIT_PART(sighting_report,'Duration:',2) as duration,
            COUNT(*) as reports
        FROM ufo
        GROUP BY 1) a
        
----------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------ Constructing and Reshaping Text--------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- can be done in simple or complex ways
-- concatenate, string aggregation, string-splitting functions
-- adding labels within the string text

SELECT 
    CONCAT(shape, ' (shape)') as shape,
    CONCAT(reports, ' reports') as reports
FROM
        (SELECT 
            split_part(split_part(sighting_report,'Duration',1),'Shape: ',2) as shape,
            COUNT(*) as reports
        FROM ufo
        GROUP BY 1) a
        
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- uniting shape and location values into a single field with a delimiter

SELECT 
    CONCAT(shape,' - ',location) as shape_location,
    reports
FROM
        (SELECT 
            split_part(split_part(sighting_report,'Shape',1),'Location: ',2) as location,
            split_part(split_part(sighting_report,'Duration',1),'Shape: ',2) as shape,
            COUNT(*) as reports
        FROM ufo
        GROUP BY 1,2) a
        
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- generating sentences that can function as a summary

SELECT 
concat('There were ',
      reports,
      ' reports of ',
      LOWER(shape),
      ' objects. The earliest sighting was ',
      TRIM(to_char(earliest,'Month')),
      ' ',
      date_part('day',earliest),
      ', ',
      date_part('year',earliest),
      ' and the most recent was ',
      TRIM(to_char(latest,'Month')),
      ' ',
      date_part('day',latest),
      ', ',
      date_part('year',latest),
      '.')
FROM
        (SELECT 
            shape,
            MIN(occurred::date) as earliest,
            MAX(occurred::date) as latest,
            SUM(reports) as reports
        FROM
               (SELECT split_part(split_part(split_part(sighting_report,' (Entered',1),'Occurred : ',2),'Reported',1) as occurred,
                split_part(split_part(sighting_report,'Duration',1),'Shape: ',2) as shape,
                COUNT(*) as reports
                FROM ufo
                GROUP BY 1,2) a
        WHERE LENGTH(occurred) >= 8
        GROUP BY 1) aa
        
----------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------- Reshaping text -------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- shaping data pivoting from rows to columns or reverse
-- special functions for reshaping text
-- string_agg function combines the individual values into a single field
-- we specify a delimiter like here in the example
-- ordering by displays the invidual values 

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- the subquery here is just running a case statement to narrow down our shape responses
-- and we're counting everything based off the combination of shape and location responses
-- from the subquery output, we're taking each row that has a particular shape value and grouping it on location
-- for example if there were 10 records of 'Alabama' location 
-- and the shapes column had some combination of 'Light','Sun','Circle','Oval','Fire','Cigar','Unknown' in those 10 records
-- then we'd get one record for 'Alabama' with a shapes column value 'Light, Sun, Circle, Oval, Fire, Cigar, Unknown'

SELECT
    location,
    string_agg(shape,', ' ORDER BY shape ASC) AS shapes
FROM
        (SELECT
            CASE WHEN split_part(split_part(sighting_report,'Duration' ,1),'Shape: ',2) = '' THEN 'Unkown'
                 WHEN split_part(split_part(sighting_report,'Duration' ,1),'Shape: ',2) = 'TRIANGULAR' THEN 'Triangle'
                 ELSE split_part(split_part(sighting_report,'Duration' ,1),'Shape: ',2) END AS shape,
            split_part(split_part(sighting_report,'Shape',1),'Location: ',2) AS location,
            COUNT(*) AS reports
        FROM ufo
        GROUP BY 1,2) a
GROUP BY 1

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- string aggregation function requires a group by
-- the opposite of string_agg is the regexp_split_to_table function for postgres

SELECT regexp_split_to_table('Red, Orange, Yellow, Blue, Purple, Green',', ')

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- the inner query splits all content in the description column based on a delimiter
-- the delimiter is any time there is one or more whitespace characters, so essentially all text with spaces between them
-- we join stop_words because we want want to where the text we pulled apart is a stop_word

SELECT
    a.word,
    b.stop_word
FROM
        (SELECT 
            regexp_split_to_table(LOWER(description),'\s+') AS word
        FROM ufo) a
LEFT JOIN stop_words b ON a.word = b.stop_word

----------------------------------------------------------------------------------------------------------------------------------------------------------

-- like above, but we've just filtered out the stop words and counted the instances of all the other words

SELECT
    a.word,
    COUNT(*) AS frequency
FROM
        (SELECT 
            regexp_split_to_table(LOWER(description),'\s+') AS word
         FROM ufo) a
LEFT JOIN stop_words b ON a.word = b.stop_word
WHERE b.stop_word IS NULL
GROUP BY 1
ORDER BY 2 DESC
----------------------------------------------------------------------------------------------------------------------------------------------------------
