/* Used by timeline app, produces one line per contiguous trip/stay segment. */
WITH timeseries AS (
    SELECT time, geom, session_id, trip, device_id
    FROM public.timeline_trajectory_points
    WHERE ('%user_id%' = '' OR device_id = ANY (
        (SELECT public.get_device_ids('%user_id%'))::TEXT[]
    ))
      AND ('%lowerbound%' = '0' OR time > '%lowerbound%'::BIGINT)
      AND ('%upperbound%' = '0' OR time < '%upperbound%'::BIGINT)
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
        PARTITION BY device_id
        ORDER BY time
    )
),

segmented_trips AS (
    SELECT
        *,
        SUM(trip_change) OVER (
            PARTITION BY device_id
            ORDER BY time
            ROWS UNBOUNDED PRECEDING
        ) AS trip_segment
    FROM trip_changes
),

grouped_trips AS (
    SELECT
        MIN(time) AS start_time,
        MAX(time) AS end_time,
        device_id,
        trip_segment,
        MIN(trip) AS trip,
        MODE() WITHIN GROUP (ORDER BY session_id) AS session_id,
        ST_MakeLine(geom ORDER BY time) AS geom
    FROM segmented_trips
    GROUP BY device_id, trip_segment
)

SELECT
    start_time,
    end_time,
    geom,
    CONCAT('https://w3id.org/MON/person.owl#person_',
        CASE WHEN '%user_id%' = '' THEN public.get_user_id(device_id)
             ELSE '%user_id%' END) AS iri,
    session_id,
    trip,
    ROW_NUMBER() OVER (ORDER BY start_time, device_id, trip_segment) AS id,
    ST_Length(ST_Transform(geom, 3857))::INTEGER AS distance_traveled
FROM grouped_trips
ORDER BY start_time, device_id, trip_segment
