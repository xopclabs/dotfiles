WITH bounds AS (
  SELECT (CURRENT_TIMESTAMP AT TIME ZONE '@timezone@')::date AS end_day
), samples AS (
  SELECT CASE WHEN measured_at < received_at - interval '2 minutes'
              THEN measured_at ELSE received_at END AS sample_time, topic, payload
  FROM mqtt_messages
), daily_hour AS (
  SELECT (sample_time AT TIME ZONE '@timezone@')::date AS day,
         EXTRACT(HOUR FROM sample_time AT TIME ZONE '@timezone@')::int AS hour,
         split_part(topic, '/', 3) AS device,
         avg((payload->>'apower')::double precision) AS watts
  FROM samples CROSS JOIN bounds
  WHERE sample_time >= ((end_day - @baselineDays@::int)::timestamp AT TIME ZONE '@timezone@')
    AND sample_time < (end_day::timestamp AT TIME ZONE '@timezone@')
    AND topic LIKE 'apartment/%/%/status/switch:0'
    AND payload->>'apower' IS NOT NULL
  GROUP BY 1, 2, 3
), devices AS (
  SELECT DISTINCT device FROM daily_hour
), profiles AS (
  SELECT hour, device AS metric, avg(watts) AS watts
  FROM daily_hour
  GROUP BY hour, device
  UNION ALL
  SELECT hour, 'All outlets' AS metric, avg(watts) AS watts
  FROM (
    SELECT day, hour, sum(watts) AS watts
    FROM daily_hour
    GROUP BY day, hour
    HAVING count(*) = (SELECT count(*) FROM devices)
  ) complete_hours
  GROUP BY hour
)
SELECT (((CURRENT_TIMESTAMP AT TIME ZONE '@timezone@')::date + make_time(h.hour, 0, 0)) AT TIME ZONE '@timezone@') AS "time",
       COALESCE((
         SELECT jsonb_object_agg(metric, watts ORDER BY metric)
         FROM profiles p WHERE p.hour = h.hour
       ), '{}'::jsonb)::text AS "Series"
FROM generate_series(0, 23) AS h(hour)
ORDER BY h.hour
