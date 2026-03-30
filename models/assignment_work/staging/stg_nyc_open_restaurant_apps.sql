-- Clean and standardize NYC Open Restaurant Applications data
-- One row per restaurant application

WITH source AS (
    SELECT * FROM {{ source('raw', 'source_nyc_open_restaurant_apps') }}
),

cleaned AS (
    SELECT
        -- keep all other raw columns unless explicitly transformed below
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
            time_of_submission,
            approved_for_sidewalk_seating,
            approved_for_roadway_seating,
            sidewalk_dimensions_length,
            sidewalk_dimensions_width,
            roadway_dimensions_length,
            roadway_dimensions_width,
            community_board,
            council_district
        ),

        -- identifiers
        CAST(objectid AS STRING) AS objectid,

        -- restaurant details
        CAST(restaurant_name AS STRING) AS restaurant_name,
        CAST(legal_business_name AS STRING) AS legal_business_name,
        CAST(doing_business_as_dba AS STRING) AS doing_business_as_dba,

        -- standardized borough
        CASE
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
            ELSE 'UNKNOWN'
        END AS borough,

        -- address info
        CAST(business_address AS STRING) AS business_address,
        CAST(street AS STRING) AS street,

        -- clean ZIP values
        CASE
            WHEN zip IS NULL THEN NULL
            WHEN UPPER(TRIM(CAST(zip AS STRING))) IN ('N/A', 'NA', '') THEN NULL
            WHEN REGEXP_CONTAINS(TRIM(CAST(zip AS STRING)), r'^\d{5}$') THEN TRIM(CAST(zip AS STRING))
            WHEN REGEXP_CONTAINS(TRIM(CAST(zip AS STRING)), r'^\d{5}-\d{4}$') THEN TRIM(CAST(zip AS STRING))
            WHEN REGEXP_CONTAINS(TRIM(CAST(zip AS STRING)), r'^\d{9}$') THEN TRIM(CAST(zip AS STRING))
            ELSE NULL
        END AS zip_code,

        -- geospatial
        CAST(latitude AS NUMERIC) AS latitude,
        CAST(longitude AS NUMERIC) AS longitude,

        -- submission timestamp
        CAST(time_of_submission AS TIMESTAMP) AS time_of_submission,

        -- seating approvals
        CAST(approved_for_sidewalk_seating AS BOOL) AS approved_for_sidewalk,
        CAST(approved_for_roadway_seating AS BOOL) AS approved_for_roadway,

        -- dimensions / measures
        CAST(sidewalk_dimensions_length AS NUMERIC) AS sidewalk_dimensions_length,
        CAST(sidewalk_dimensions_width AS NUMERIC) AS sidewalk_dimensions_width,
        CAST(roadway_dimensions_length AS NUMERIC) AS roadway_dimensions_length,
        CAST(roadway_dimensions_width AS NUMERIC) AS roadway_dimensions_width,

        -- admin fields
        CAST(community_board AS STRING) AS community_board,
        CAST(council_district AS STRING) AS council_district,

        -- metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source

    WHERE objectid IS NOT NULL
      AND time_of_submission IS NOT NULL
      AND borough IS NOT NULL

    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY objectid
        ORDER BY time_of_submission DESC
    ) = 1
)

SELECT * FROM cleaned