WITH distinct_devices AS (
    SELECT array_agg(device_id::text) AS device_list
    FROM (SELECT DISTINCT device_id FROM devices) AS distinct_devices
),

timeseries AS (
    SELECT
        timeseries.time,
        timeseries.geom,
        timeseries.trip,
        timeseries.device_id
    FROM public.get_location_table(
        (SELECT device_list FROM distinct_devices)
    ) AS timeseries
    WHERE ('%device_id%' = '' OR timeseries.device_id = '%device_id%')
      AND (%lowerbound% = 0 OR timeseries.time > %lowerbound%)
      AND (%upperbound% = 0 OR timeseries.time < %upperbound%)
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
