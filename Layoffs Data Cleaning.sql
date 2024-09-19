 -- DATA CLEANING of combined_layoff dataset

 -- Create a cleaning stage table from layoffs database
 -- First thing we want to do is create a staging table. This is the one we will work in and clean the data. We want a table with the raw data in case something happens


-- DROP TABLE IF EXISTS public.layoff_staging;

CREATE TABLE IF NOT EXISTS  public.layoff_staging     -- Table: public.layoff_staging
(
    company character varying(50) ,
    location character varying(50) ,
    industry character varying(50) ,
    date date,
    stage character varying(50) ,
    country character varying(50),
    funds_raised numeric,
    total_laid_off  INTEGER,
    percentage_laid_off DOUBLE PRECISION 
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.layoff_staging
    OWNER to [localhost_name];

-- The DATE datatype is recognised as an INTEGER datatype by the engine
-- It has to be converted to DATE datatype

        -- Step 1: Add a new temporary column
        ALTER TABLE world_layoffs ADD COLUMN temp_date DATE;

        -- Step 2: Convert the integer date to a proper date format and update the temporary column
        UPDATE world_layoffs
        SET temp_date = TO_DATE(CAST(date AS TEXT), 'YYYY-MM-DD');

        -- Step 3: Drop the old integer date column
        ALTER TABLE world_layoffs DROP COLUMN date;

        -- Step 4: Rename the temporary column to the original column name
        ALTER TABLE world_layoffs RENAME COLUMN temp_date TO date;

SELECT pg_typeof(date) FROM world_layoffs;


SELECT date FROM world_layoffs
WHERE date = '0';

-- insert data from combined_layoff into layoff_staging

INSERT INTO public.layoff_staging
SELECT *
FROM public.world_layoffs;

SELECT * FROM layoff_staging;

-- use row number to identify duplicates

SELECT * ,
ROW_NUMBER() OVER(
    PARTITION BY company, location , industry, total_laid_off, percentage_laid_off, date, stage, country
    ) AS row_num
FROM layoff_staging;

-- identify duplicates using a cte where the row number is more than 1

WITH duplicate_cte AS
(
    SELECT * ,
ROW_NUMBER() OVER(
    PARTITION BY company, location , industry, total_laid_off, percentage_laid_off, date, stage, country
    ) AS row_num
FROM layoff_staging

)

SELECT *
FROM duplicate_cte
WHERE row_num > 1;


-- If there was any column with a rw_number more than 1, we do the foloowing

CREATE TABLE IF NOT EXISTS  public.layoff_staging_2    -- Table: public.layoff_staging
(
    company character varying(50) COLLATE pg_catalog."default",
    location character varying(50) COLLATE pg_catalog."default",
    industry character varying(50) COLLATE pg_catalog."default",
    date date,
    stage character varying(50) COLLATE pg_catalog."default",
    country character varying(50) COLLATE pg_catalog."default",
    funds_raised numeric(10,0),
    total_laid_off character varying(10) COLLATE pg_catalog."default",
    percentage_laid_off character varying(10) COLLATE pg_catalog."default"
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.layoff_staging_2
    OWNER to alicemaphosa;

-- ALTER layoff_staging_2 to enter the row_number


ALTER TABLE layoff_staging_2
ADD COLUMN row_num INTEGER;


-- insert data from layoff_staging into layoff_staging_2
-- new table layoffs_staging_2 is created with an additional column row_num

-- INSERT INTO layoff_staging_2
 --SELECT * ,
--ROW_NUMBER() OVER(
  --  PARTITION BY company, location , industry, total_laid_off, percentage_laid_off, date, stage, country, funds_raised
   -- ) AS row_num
--FROM layoff_staging;


INSERT INTO layoff_staging_2 (company, location, industry, total_laid_off, percentage_laid_off, date, stage, country, funds_raised)
SELECT 
    company, 
    location, 
    industry, 
    total_laid_off, 
    percentage_laid_off, 
    date, 
    stage, 
    country, 
    funds_raised
  
FROM layoff_staging;


SELECT *
FROM layoff_staging_2;

ALTER TABLE layoff_staging_2
DROP COLUMN row_num;


-- delete duplicates , that is those with a row_num greater than 1
-- any row with a row number of more than 2 means it is a duplicate and must be deleted from the table
-- 2992  records deleted

--DELETE
--SELECT *,
     --ROW_NUMBER() OVER(
        --PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, date, stage, country, funds_raised
    ) --AS row_num
--FROM layoffs_staging_2
--WHERE row_num > 1;

WITH cte AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, date, stage, country, funds_raised
            ORDER BY company
        ) AS row_num
    FROM layoff_staging_2
)
DELETE FROM layoff_staging_2
USING cte
WHERE layoff_staging_2.company = cte.company
  AND layoff_staging_2.location = cte.location
  AND layoff_staging_2.industry = cte.industry
  AND layoff_staging_2.total_laid_off = cte.total_laid_off
  AND layoff_staging_2.percentage_laid_off = cte.percentage_laid_off
  AND layoff_staging_2.date = cte.date
  AND layoff_staging_2.stage = cte.stage
  AND layoff_staging_2.country = cte.country
  AND layoff_staging_2.funds_raised = cte.funds_raised
  AND cte.row_num > 1;


-- 2. Standardize data

SELECT company, TRIM(company)
FROM layoff_staging_2;

-- updated company column without spaces
-- 8866 records updated/

UPDATE layoff_staging_2
SET company = TRIM(company)

-- From the original dataset there is an issue of FinTech vs Finance & Crypto vs Crypto Currency vs CryptoCurrency

SELECT DISTINCT industry
FROM layoff_staging_2
ORDER BY 1;

-- to fix the above under normal circumstances identify the anomaly 
SELECT *
FROM layoff_staging_2
WHERE industry LIKE 'Crypto%'

-- Fix the anomaly - Crypto Currency, CryptoCurrency to Crypto
-- 376 records updated

UPDATE layoff_staging_2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

SELECT DISTINCT country
FROM layoff_staging_2
ORDER BY 1

-- Remove the dot on United States using TRIM & TRAILING

SELECT DISTINCT country , 
       TRIM(TRAILING '.' FROM country)
FROM layoff_staging_2
ORDER BY 1

-- Update the country column
-- 5756 records updated

UPDATE layoff_staging_2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%'

SELECT *
FROM layoff_staging_2;

-- Change date from a string to Date Format

-- 3. Removing NULLS or Blanks

SELECT company, industry
FROM layoff_staging_2
WHERE (industry IS NULL OR industry = '' ) 
    OR
       company IS NULL OR company = '';

-- Where the industry lets set it to null and later update it with their respective industries

SELECT company, industry
FROM layoff_staging_2 
WHERE company = 'Airbnb'  

-- UPDATE USING THE TRAVEL INDUSTRY

UPDATE layoff_staging_2
SET industry = 'Travel'
WHERE company = 'Airbnb'

SELECT company, industry
FROM layoff_staging_2 
WHERE company = 'Appsmith' -- NO INDUSTRY FOR THIS COMPANY NAME

SELECT company, industry
FROM layoff_staging_2 
WHERE company = 'Carvana'

-- UPDATE USING THE TRANSPORTATION INDUSTRY

UPDATE layoff_staging_2
SET industry = 'Transportation' 
WHERE company = 'Carvana'

SELECT company, industry
FROM layoff_staging_2 
WHERE company = 'Juul' 

-- UPDATE USING THE CONSUMER INDUSTRY

UPDATE layoff_staging_2
SET industry = 'Consumer'
WHERE company = 'Juul'

-- use self join to identify any company without an industry

SELECT t1.industry, t2.industry
FROM layoff_staging_2 t1
JOIN layoff_staging_2 t2
    ON t1.company = t2.company
WHERE t1.industry IS NULL 
AND t2.industry IS NOT NULL

SELECT *
FROM layoff_staging_2;

-- deletion of NULL rows
-- 1178 records deleted
SELECT *
FROM layoff_staging_2
WHERE total_laid_off IS NULL
    AND percentage_laid_off IS NULL


DELETE
FROM layoff_staging_2
WHERE total_laid_off IS NULL
      AND percentage_laid_off IS NULL

SELECT *
FROM layoff_staging_2
WHERE total_laid_off IS NULL;

-- For NULLs not deletable in the total laid_off column will be changed to 0

UPDATE layoff_staging_2
SET total_laid_off = '0'
WHERE total_laid_off IS NULL;

ALTER TABLE layoff_staging_2
ALTER COLUMN total_laid_off TYPE INTEGER USING total_laid_off::INTEGER;

DELETE
FROM layoff_staging_2            -- 641 deleted
WHERE total_laid_off = '0'

-- DELETE unnecessary funds_raised column

ALTER TABLE layoff_staging_2
DROP COLUMN funds_raised;

SELECT * FROM layoff_staging_2 WHERE total_laid_off !~ '^[0-9]+$' OR percentage_laid_off !~ '^[0-9]+$';

ALTER TABLE layoff_staging_2
ALTER COLUMN total_laid_off TYPE integer USING total_laid_off::integer,
ALTER COLUMN percentage_laid_off TYPE double precision USING percentage_laid_off::double precision;


USE COALESCE AND CASE STATEMENT
CHANGE THE DATATYPES ALONG THE WAY






