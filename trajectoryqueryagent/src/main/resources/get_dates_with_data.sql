WITH available_dates AS (
    SELECT DISTINCT local_date
    FROM public.device_available_dates
    WHERE timezone = ? AND device_id = ANY (?::text[])
)
SELECT EXTRACT(YEAR FROM local_date) AS year,
       EXTRACT(MONTH FROM local_date) AS month,
       array_agg(EXTRACT(DAY FROM local_date) ORDER BY local_date) AS days
FROM available_dates
GROUP BY EXTRACT(YEAR FROM local_date), EXTRACT(MONTH FROM local_date)
ORDER BY year, month;
