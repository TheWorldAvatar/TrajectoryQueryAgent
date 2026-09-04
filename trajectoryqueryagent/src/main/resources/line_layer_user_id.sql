/* Used by timeline app, produces one line per contiguous trip/stay segment. */
WITH distinct_devices AS (
    SELECT array_agg(device_id::text) AS device_list
    FROM (SELECT DISTINCT device_id FROM devices) AS distinct_devices
),

timeseries AS (
    SELECT
        timeseries.time,
        timeseries.geom,
        timeseries.session_id,
        timeseries.trip,
        timeseries.device_id,
        timeseries.user_id
    FROM public.get_location_table(
        (SELECT device_list FROM distinct_devices)
    ) AS timeseries
    WHERE ('%user_id%' = '' OR timeseries.user_id = '%user_id%')
      AND ('%lowerbound%' = '0' OR timeseries.time > '%lowerbound%'::BIGINT)
      AND ('%upperbound%' = '0' OR timeseries.time < '%upperbound%'::BIGINT)
),

trip_changes AS (
    SELECT
        *,
        CASE
            WHEN LAG(time) OVER device_timeline IS NULL
              OR LAG(trip) OVER device_timeline IS DISTINCT FROM trip
            THEN 1
            ELSE 0
        END AS trip_change
    FROM timeseries
    WINDOW device_timeline AS (
        PARTITION BY user_id, device_id
        ORDER BY time
    )
),

segmented_trips AS (
    SELECT
        *,
        SUM(trip_change) OVER (
            PARTITION BY user_id, device_id
            ORDER BY time
            ROWS UNBOUNDED PRECEDING
        ) AS trip_segment
    FROM trip_changes
),

grouped_trips AS (
    SELECT
        MIN(time) AS start_time,
        MAX(time) AS end_time,
        user_id,
        device_id,
        MIN(trip) AS trip,
        MODE() WITHIN GROUP (ORDER BY session_id) AS session_id,
        ST_MakeLine(geom ORDER BY time) AS geom
    FROM segmented_trips
    GROUP BY user_id, device_id, trip_segment
)

SELECT
    start_time,
    end_time,
    geom,
    CONCAT('https://w3id.org/MON/person.owl#person_', user_id) AS iri,
    session_id,
    trip,
    ROW_NUMBER() OVER (ORDER BY start_time) AS id,
    ST_Length(ST_Transform(geom, 3857))::INTEGER AS distance_traveled
FROM grouped_trips
ORDER BY start_time
