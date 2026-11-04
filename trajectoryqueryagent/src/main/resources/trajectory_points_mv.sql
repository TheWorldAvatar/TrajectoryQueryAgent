CREATE OR REPLACE FUNCTION public.get_trajectory_points(device_id_array TEXT[])
RETURNS TABLE (
    device_id TEXT,
    "time" BIGINT,
    geom geometry,
    session_id CHARACTER VARYING,
    trip INTEGER,
    speed DOUBLE PRECISION,
    altitude DOUBLE PRECISION,
    bearing DOUBLE PRECISION,
    activity_type CHARACTER VARYING
)
AS $$
DECLARE
    current_device_id TEXT;
BEGIN
    FOREACH current_device_id IN ARRAY COALESCE(device_id_array, ARRAY[]::TEXT[]) LOOP
        RETURN QUERY
        SELECT
            current_device_id,
            ROUND(g.time * 1000.0)::BIGINT,
            g.geom,
            s.session_id,
            t.trip,
            speed_data.speed,
            altitude_data.altitude,
            bearing_data.bearing,
            activity.activity_type
        FROM public.get_geom_table(ARRAY[current_device_id]) AS g
        LEFT JOIN public.get_session_id_table(ARRAY[current_device_id]) AS s
            ON s.time = g.time
        LEFT JOIN public.get_trip_table(ARRAY[current_device_id]) AS t
            ON t.time = g.time
        LEFT JOIN public.get_speed_table(ARRAY[current_device_id]) AS speed_data
            ON speed_data.time = g.time
        LEFT JOIN public.get_altitude_table(ARRAY[current_device_id]) AS altitude_data
            ON altitude_data.time = g.time
        LEFT JOIN public.get_bearing_table(ARRAY[current_device_id]) AS bearing_data
            ON bearing_data.time = g.time
        LEFT JOIN LATERAL (
            SELECT a.activity_type
            FROM (
                SELECT DISTINCT d.device_id
                FROM public.devices AS d
                WHERE d.device_id = current_device_id
                  AND d.sensor_class = 'Activity'
            ) AS activity_device
            CROSS JOIN LATERAL public.get_activity_type_table(
                ARRAY[activity_device.device_id::TEXT]
            ) AS a
            WHERE ABS(ROUND(g.time * 1000.0)::BIGINT
                    - ROUND(a.time * 1000.0)::BIGINT) <= 5000
            ORDER BY ABS(ROUND(g.time * 1000.0)::BIGINT
                       - ROUND(a.time * 1000.0)::BIGINT)
            LIMIT 1
        ) AS activity ON TRUE;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE MATERIALIZED VIEW IF NOT EXISTS public.trajectory_points_mv AS
SELECT points.*
FROM public.get_trajectory_points(
    ARRAY(SELECT DISTINCT d.device_id::TEXT FROM public.devices AS d)
) AS points;

CREATE INDEX IF NOT EXISTS trajectory_points_mv_device_time_idx
    ON public.trajectory_points_mv (device_id, time);

ANALYZE public.trajectory_points_mv;
