WITH bounds AS (
  SELECT $__timeFrom()::timestamptz AS start_at,
         $__timeTo()::timestamptz AS end_at
), selected_device AS (
  SELECT split_part(topic, '/', 3) AS device,
         GREATEST(max((payload->'aenergy'->>'total')::double precision)
           - min((payload->'aenergy'->>'total')::double precision), 0) / 1000.0 AS kwh
  FROM mqtt_messages, bounds
  WHERE COALESCE(measured_at, received_at) >= bounds.start_at AND COALESCE(measured_at, received_at) <= bounds.end_at
    AND topic LIKE 'apartment/%/%/status/switch:0'
    AND payload ? 'aenergy'
    AND payload->'aenergy'->>'total' IS NOT NULL
  GROUP BY 1
  HAVING count(*) >= 2
), windows AS (
  SELECT n,
         ((b.start_at AT TIME ZONE '@timezone@') - n * interval '1 day')
           AT TIME ZONE '@timezone@' AS start_at,
         ((b.end_at AT TIME ZONE '@timezone@') - n * interval '1 day')
           AT TIME ZONE '@timezone@' AS end_at
  FROM bounds b CROSS JOIN generate_series(1, @baselineDays@::int) AS days(n)
  WHERE b.end_at - b.start_at <= interval '1 day'
  UNION ALL
  SELECT n,
         b.start_at - n * (b.end_at - b.start_at) AS start_at,
         b.end_at - n * (b.end_at - b.start_at) AS end_at
  FROM bounds b CROSS JOIN LATERAL generate_series(
    1, floor(EXTRACT(EPOCH FROM (@baselineDays@::int * interval '1 day'))
             / NULLIF(EXTRACT(EPOCH FROM (b.end_at - b.start_at)), 0))::int
  ) AS blocks(n)
  WHERE b.end_at - b.start_at > interval '1 day'
), covered_device AS (
  SELECT w.n, split_part(m.topic, '/', 3) AS device,
         GREATEST(max((m.payload->'aenergy'->>'total')::double precision)
           - min((m.payload->'aenergy'->>'total')::double precision), 0) / 1000.0 AS kwh
  FROM windows w CROSS JOIN bounds b
  JOIN mqtt_messages m ON COALESCE(m.measured_at, m.received_at) >= w.start_at AND COALESCE(m.measured_at, m.received_at) <= w.end_at
    AND m.topic LIKE 'apartment/%/%/status/switch:0'
    AND m.payload ? 'aenergy'
    AND m.payload->'aenergy'->>'total' IS NOT NULL
  WHERE w.end_at <= b.start_at
    AND (b.end_at - b.start_at <= interval '1 day'
      OR w.start_at >= b.start_at - @baselineDays@::int * interval '1 day')
    AND split_part(m.topic, '/', 3) IN (SELECT device FROM selected_device)
  GROUP BY w.n, w.start_at, w.end_at, split_part(m.topic, '/', 3)
  HAVING count(*) >= 2
    AND min(COALESCE(m.measured_at, m.received_at)) <= w.start_at + interval '15 minutes'
    AND max(COALESCE(m.measured_at, m.received_at)) >= w.end_at - interval '15 minutes'
), complete_windows AS (
  SELECT n, sum(kwh) AS kwh
  FROM covered_device
  GROUP BY n
  HAVING count(*) = (SELECT count(*) FROM selected_device)
), baseline AS (
  SELECT avg(kwh) AS kwh FROM complete_windows
), selected AS (
  SELECT sum(kwh) AS kwh FROM selected_device
)
SELECT CASE WHEN pct IS NOT NULL THEN
    CASE WHEN pct < 0 THEN '-' WHEN pct > 0 THEN '+' ELSE '' END
    || to_char(abs(pct), 'FM999999990.0') || '%'
  END AS "Δ vs avg"
FROM (
  SELECT CASE WHEN baseline.kwh > 0 AND selected.kwh IS NOT NULL
    THEN round(((selected.kwh / baseline.kwh - 1) * 100.0)::numeric, 1)
    END AS pct
  FROM baseline CROSS JOIN selected
) comparison
