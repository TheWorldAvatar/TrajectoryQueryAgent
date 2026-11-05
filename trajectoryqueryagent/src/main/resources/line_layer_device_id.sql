WITH distinct_devices AS (
    SELECT 
        array_agg(device_id::text) as device_list
    FROM 
        (SELECT DISTINCT device_id FROM devices) AS distinct_devices
),

timeseries AS (
    SELECT
        timeseries.time AS time,
        timeseries.speed AS speed,
        timeseries.altitude AS altitude,
        timeseries.geom AS geom,
        timeseries.bearing AS bearing,
        timeseries.session_id AS session_id,
        timeseries.trip AS trip,
        timeseries.device_id AS device_id
    FROM
        public.get_location_table((SELECT device_list FROM distinct_devices)) AS timeseries
    ORDER BY time
),

line AS (
    SELECT 
        ts.time as time,
        LAG(ts.geom) OVER device_timeline AS prev_geom,
        LAG(ts.trip) OVER device_timeline AS prev_trip,
        LAG(ts.session_id) OVER device_timeline AS prev_session_id,
        ST_MakeLine(LAG(ts.geom) OVER device_timeline, ts.geom) AS geom,
        ts.speed AS speed,
        ts.altitude AS altitude,
        ts.bearing AS bearing,
        ts.session_id AS session_id,
        ts.trip AS trip,
        ts.device_id AS device_id,
        get_device_iri(ts.device_id) AS iri
    FROM 
        timeseries ts
    WINDOW device_timeline AS (
        PARTITION BY ts.device_id
        ORDER BY ts.time
    )
)

SELECT 
    time, geom, speed, altitude, bearing, trip, iri
FROM 
    line
WHERE
    line.prev_geom IS NOT NULL
    AND line.prev_trip IS NOT DISTINCT FROM line.trip
    AND line.prev_session_id IS NOT DISTINCT FROM line.session_id
    AND ('%device_id%' = '' OR device_id = '%device_id%')
