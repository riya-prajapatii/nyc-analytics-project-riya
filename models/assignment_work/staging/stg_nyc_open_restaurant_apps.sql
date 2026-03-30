-- Clean and standardize NYC Open Restaurant Applications data
-- One row per restaurant application

WITH source AS (
   SELECT * FROM {{ source('raw', 'source_nyc_open_restaurant_apps') }}
),

cleaned AS (
   SELECT
       -- Get all columns from source, except ones we're transforming below
       * EXCEPT (
           objectid,
           restaurant_name,
           legal_business_name,
           doing_business_as_dba,
           borough,
           business_address,
           zip,
           time_of_submission,
           latitude,
           longitude,
           approved_for_sidewalk_seating,
           approved_for_roadway_seating
       ),

       -- Identifiers
       CAST(objectid AS STRING) AS application_id,

       -- Restaurant details (standardizing to Title Case/Trim)
       UPPER(TRIM(CAST(restaurant_name AS STRING))) AS restaurant_name,
       CAST(legal_business_name AS STRING) AS legal_name,
       CAST(doing_business_as_dba AS STRING) AS dba_name,

       -- Date/Time
       CAST(time_of_submission AS TIMESTAMP) AS submitted_at,

       -- Seating Approvals (Converting to Boolean/Clearer names)
       CASE 
           WHEN UPPER(TRIM(approved_for_sidewalk_seating)) = 'YES' THEN TRUE 
           ELSE FALSE 
       END AS is_sidewalk_seating_approved,
       
       CASE 
           WHEN UPPER(TRIM(approved_for_roadway_seating)) = 'YES' THEN TRUE 
           ELSE FALSE 
       END AS is_roadway_seating_approved,

       -- Location - clean zip code using the same logic as 311 for consistency
       CASE
           WHEN UPPER(TRIM(CAST(zip AS STRING))) IN ('N/A', 'NA') THEN NULL
           WHEN LENGTH(CAST(zip AS STRING)) = 5 THEN CAST(zip AS STRING)
           ELSE NULL -- Simplification for restaurants as they usually have 5-digit zips
       END AS zip_code,

       -- Location - standardized borough
       CASE
           WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
           WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
           WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
           WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
           WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
           ELSE 'UNKNOWN'
       END AS borough,

       CAST(business_address AS STRING) AS business_address,
       CAST(latitude AS FLOAT64) AS latitude,
       CAST(longitude AS FLOAT64) AS longitude,

       -- Metadata
       CURRENT_TIMESTAMP() AS _stg_loaded_at

   FROM source

   -- Filters
   WHERE objectid IS NOT NULL
   AND time_of_submission IS NOT NULL
   -- Only include applications from the last 7 years to match the 311 data scope
   AND CAST(time_of_submission AS DATE) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 YEAR)
   AND borough IS NOT NULL

   -- Deduplicate based on objectid
   QUALIFY ROW_NUMBER() OVER (PARTITION BY objectid ORDER BY time_of_submission DESC) = 1
)

SELECT * FROM cleaned