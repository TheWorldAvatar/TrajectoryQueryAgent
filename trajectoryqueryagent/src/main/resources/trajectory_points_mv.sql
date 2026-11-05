-- Device-only extraction: existing location/activity functions remain unchanged.
CREATE OR REPLACE FUNCTION public.get_trajectory_points(device_id_array TEXT[])
RETURNS TABLE (
    device_id TEXT,
    "time" BIGINT,
    geom geometry,
    session_id CHARACTER VARYING,
    trip INTEGER
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
            t.trip
        FROM public.get_geom_table(ARRAY[current_device_id]) AS g
        LEFT JOIN public.get_session_id_table(ARRAY[current_device_id]) AS s
            ON s.time = g.time
        LEFT JOIN public.get_trip_table(ARRAY[current_device_id]) AS t
            ON t.time = g.time;
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
