WITH timeseries AS (
    SELECT * FROM public.timeline_trajectory_points
    WHERE ('%device_id%' = '' OR device_id = '%device_id%')
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
)

SELECT
    ST_Buffer(
        ST_Transform(ST_MakeLine(ts.geom ORDER BY ts.time), 3857),
        100
    ) AS geom,
    MIN(ts.trip) AS trip,
    get_device_iri(ts.device_id) AS iri
FROM segmented_trips ts
GROUP BY ts.device_id, ts.trip_segment
