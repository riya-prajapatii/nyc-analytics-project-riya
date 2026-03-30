-- Clean and standardize NYC Open Restaurant application data
-- One row per application record

WITH source AS (
    SELECT *
    FROM {{ source('raw_restaurants', 'source_nyc_open_restaurant_apps') }}
),

cleaned AS (
    SELECT
        * EXCEPT (
            objectid,
            time_of_submission,
            seating_interest_sidewalk,
            seating_interest_roadway,
            approved_for_sidewalk_seating,
            approved_for_roadway_seating,
            borough,
            zip_code,
            latitude,
            longitude
        ),

        -- Identifier
        CAST(objectid AS STRING) AS objectid,

        -- Submission timestamp
        CAST(time_of_submission AS TIMESTAMP) AS time_of_submission,

        -- Seating interest
        CAST(seating_interest_sidewalk AS STRING) AS seating_interest_sidewalk,
        CAST(seating_interest_roadway AS STRING) AS seating_interest_roadway,

        -- Approval flags
        CASE
            WHEN UPPER(TRIM(CAST(approved_for_sidewalk_seating AS STRING))) IN ('YES', 'Y', 'TRUE') THEN TRUE
            WHEN UPPER(TRIM(CAST(approved_for_sidewalk_seating AS STRING))) IN ('NO', 'N', 'FALSE') THEN FALSE
            ELSE NULL
        END AS approved_for_sidewalk_seating,

        CASE
            WHEN UPPER(TRIM(CAST(approved_for_roadway_seating AS STRING))) IN ('YES', 'Y', 'TRUE') THEN TRUE
            WHEN UPPER(TRIM(CAST(approved_for_roadway_seating AS STRING))) IN ('NO', 'N', 'FALSE') THEN FALSE
            ELSE NULL
        END AS approved_for_roadway_seating,

        -- Borough cleaning
        CASE
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
            ELSE 'UNKNOWN'
        END AS borough,

        -- ZIP cleaning
        CASE
            WHEN UPPER(TRIM(CAST(zip_code AS STRING))) IN ('N/A', 'NA', '') THEN NULL
            WHEN REGEXP_CONTAINS(TRIM(CAST(zip_code AS STRING)), r'^\d{5}$') THEN TRIM(CAST(zip_code AS STRING))
            WHEN REGEXP_CONTAINS(TRIM(CAST(zip_code AS STRING)), r'^\d{5}-\d{4}$') THEN TRIM(CAST(zip_code AS STRING))
            ELSE NULL
        END AS zip_code,

        -- Coordinates
        CAST(latitude AS NUMERIC) AS latitude,
        CAST(longitude AS NUMERIC) AS longitude,

        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source
    WHERE objectid IS NOT NULL
)

SELECT *
FROM cleaned
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY objectid
    ORDER BY time_of_submission DESC
) = 1