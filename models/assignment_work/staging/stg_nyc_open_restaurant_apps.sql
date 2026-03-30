-- Clean and standardize NYC Open Restaurant Applications data
-- One row per application

WITH source AS (
    SELECT * 
    FROM {{ source('raw', 'source_nyc_open_restaurant_apps') }}
),

cleaned AS (
    SELECT
        -- Identifier
        CAST(objectid AS STRING) AS application_id,

        -- Restaurant info
        CAST(restaurant_name AS STRING) AS restaurant_name,

       -- CAST(`Time of Submission` AS TIMESTAMP) AS time_of_submission

        -- Location cleaning (zip)
        CASE
            WHEN UPPER(TRIM(CAST(zip AS STRING))) IN ('N/A', 'NA') THEN NULL
            WHEN LENGTH(CAST(zip AS STRING)) IN (5, 9) THEN CAST(zip AS STRING)
            WHEN LENGTH(CAST(zip AS STRING)) = 10
                AND REGEXP_CONTAINS(CAST(zip AS STRING), r'^\d{5}-\d{4}')
            THEN CAST(zip AS STRING)
            ELSE NULL
        END AS zip,

        -- Borough standardization
        CASE
            WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
            WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
            WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
            WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
            ELSE 'UNKNOWN'
        END AS borough,

        -- Address + coordinates
        CAST(business_address AS STRING) AS business_address,
        CAST(latitude AS FLOAT64) AS latitude,
        CAST(longitude AS FLOAT64) AS longitude,

        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at

   
    FROM source

    -- Filters
    WHERE objectid IS NOT NULL
     -- AND `Time of Submission` IS NOT NULL
      AND borough IS NOT NULL

    -- Deduplicate
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY objectid 
       -- ORDER BY `Time of Submission` DESC
    ) = 1
)

SELECT * FROM cleaned