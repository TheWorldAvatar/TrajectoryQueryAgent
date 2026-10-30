WITH distinct_devices AS (
    SELECT array_agg(device_id::text) AS device_list
    FROM (
        SELECT DISTINCT device_id
        FROM devices
        WHERE sensor_class = 'Activity'
    ) AS distinct_devices
),

timeseries AS (
    SELECT *
    FROM public.get_location_table(
        (SELECT device_list FROM distinct_devices)
    )
),

activity_data AS (
    SELECT *
    FROM public.get_activity_table(
        (SELECT device_list FROM distinct_devices)
    )
),

trip_data AS (
    SELECT
        t.*,
        activity.activity_type
    FROM timeseries t
    LEFT JOIN LATERAL (
        SELECT
            a.activity_type
        FROM activity_data a
        WHERE a.device_id = t.device_id
          AND ABS(t.time - a.time) <= 5000
        ORDER BY
            ABS(t.time - a.time)
        LIMIT 1
    ) AS activity ON TRUE
    WHERE ('%user_id%' = '' OR t.user_id = '%user_id%')
      AND ('%lowerbound%' = '0' OR t.time > '%lowerbound%'::BIGINT)
      AND ('%upperbound%' = '0' OR t.time < '%upperbound%'::BIGINT)
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
    FROM trip_data
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

timed_activity_data AS (
    SELECT
        *,
        GREATEST(
            LEAD(time) OVER (
                PARTITION BY user_id, device_id, trip_segment
                ORDER BY time
            ) - time,
            0
        ) AS activity_duration
    FROM segmented_trips
),

activity_durations AS (
    SELECT
        user_id,
        device_id,
        trip_segment,
        COALESCE(activity_type, 'unknown') AS activity_type,
        SUM(activity_duration) AS activity_duration
    FROM timed_activity_data
    GROUP BY
        user_id,
        device_id,
        trip_segment,
        COALESCE(activity_type, 'unknown')
),

activity_totals AS (
    SELECT
        user_id,
        device_id,
        trip_segment,
        SUM(activity_duration) AS total_duration
    FROM activity_durations
    GROUP BY user_id, device_id, trip_segment
),

activity_proportions AS (
    SELECT
        durations.user_id,
        durations.device_id,
        durations.trip_segment,
        JSONB_OBJECT_AGG(
            durations.activity_type,
            ROUND(
                durations.activity_duration::numeric
                / NULLIF(totals.total_duration, 0),
                4
            )
        ) AS activity_proportions
    FROM activity_durations durations
    JOIN activity_totals totals
      ON totals.user_id = durations.user_id
     AND totals.device_id = durations.device_id
     AND totals.trip_segment = durations.trip_segment
    GROUP BY
        durations.user_id,
        durations.device_id,
        durations.trip_segment
),

grouped_trips AS (
    SELECT
        MIN(time) AS start_time,
        MAX(time) AS end_time,
        user_id,
        device_id,
        trip_segment,
        MIN(trip) AS trip,
        MODE() WITHIN GROUP (ORDER BY session_id) AS session_id,
        ST_MakeLine(geom ORDER BY time) AS geom
    FROM segmented_trips
    GROUP BY user_id, device_id, trip_segment
)

SELECT
    ROW_NUMBER() OVER (ORDER BY trips.start_time) AS id,
    trips.start_time,
    trips.end_time,
    trips.user_id,
    proportions.activity_proportions,
    trips.session_id,
    trips.trip,
    trips.geom,
    ST_Length(ST_Transform(trips.geom, 3857))::INTEGER AS distance_traveled,
    CONCAT('https://w3id.org/MON/person.owl#person_', trips.user_id) AS iri
FROM grouped_trips trips
JOIN activity_proportions proportions
  ON proportions.user_id = trips.user_id
 AND proportions.device_id = trips.device_id
 AND proportions.trip_segment = trips.trip_segment
ORDER BY trips.start_time
