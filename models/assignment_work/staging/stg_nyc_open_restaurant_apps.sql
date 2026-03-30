-- Clean and standardize NYC Open Restaurant Applications data
-- One row per application

WITH source AS (
    SELECT * 
    FROM {{ source('raw', 'source_nyc_open_restaurant_apps') }}
),

cleaned AS (
    SELECT
        * EXCEPT (
            objectid,
            restaurant_name,
            legal_business_name,
            doing_business_as_dba,
            borough,
            business_address,
            street,
            zip,
            latitude,
            longitude,
            time_of_submission
        ),
        CAST(objectid AS STRING) AS application_id,
        CAST(restaurant_name AS STRING) AS restaurant_name,
        CAST(legal_business_name AS STRING) AS legal_business_name,
        CAST(doing_business_as_dba AS STRING) AS dba_name,
        CASE
            WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
            WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
            WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
            WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
            ELSE 'UNKNOWN'
        END AS borough,
        CAST(business_address AS STRING) AS business_address,
        CAST(street AS STRING) AS street,
        CASE
            WHEN UPPER(TRIM(CAST(zip AS STRING))) IN ('N/A', 'NA') THEN NULL
            WHEN LENGTH(CAST(zip AS STRING)) IN (5, 9) THEN CAST(zip AS STRING)
            WHEN LENGTH(CAST(zip AS STRING)) = 10
                 AND REGEXP_CONTAINS(CAST(zip AS STRING), r'^\d{5}-\d{4}') THEN CAST(zip AS STRING)
            ELSE NULL
        END AS zip,
        CAST(latitude AS FLOAT64) AS latitude,
        CAST(longitude AS FLOAT64) AS longitude,
        CAST(time_of_submission AS TIMESTAMP) AS time_of_submission,
        approved_for_sidewalk_seating,
        approved_for_roadway_seating,
        sidewalk_dimensions_length,
        sidewalk_dimensions_width,
        roadway_dimensions_length,
        roadway_dimensions_width,
        community_board,
        council_district,
        CURRENT_TIMESTAMP() AS _stg_loaded_at
    FROM source
    WHERE objectid IS NOT NULL
      AND borough IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY objectid
        ORDER BY time_of_submission ASC
    ) = 1
)

SELECT *
FROM cleaned