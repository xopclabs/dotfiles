WITH bounds AS (
  SELECT
    ((CURRENT_TIMESTAMP AT TIME ZONE '@timezone@')::date - 13) AS first_day,
    (CURRENT_TIMESTAMP AT TIME ZONE '@timezone@')::date AS today,
    CURRENT_TIMESTAMP AS now_ts
), per_device_day AS (
  SELECT
    (COALESCE(measured_at, received_at) AT TIME ZONE '@timezone@')::date AS local_day,
    split_part(topic, '/', 3) AS device,
    GREATEST(
      max((payload->'aenergy'->>'total')::double precision)
      - min((payload->'aenergy'->>'total')::double precision),
      0
    ) / 1000.0 AS kwh
  FROM mqtt_messages, bounds
  WHERE COALESCE(measured_at, received_at) >= (first_day::timestamp AT TIME ZONE '@timezone@')
    AND COALESCE(measured_at, received_at) <= now_ts
    AND topic LIKE 'apartment/%/%/status/switch:0'
    AND payload ? 'aenergy'
  GROUP BY 1, 2
), days AS (
  SELECT generate_series(first_day, today, interval '1 day')::date AS day
  FROM bounds
)
SELECT
  CASE
    WHEN days.day = bounds.today THEN to_char(days.day, 'Dy DD') || ' · now'
    ELSE to_char(days.day, 'Dy DD')
  END AS "Day",
  CASE
    WHEN @outletBreakdown@ THEN
      COALESCE((
        SELECT jsonb_object_agg(
          p.device,
          round(p.kwh::numeric, 2)
          ORDER BY p.device
        )
        FROM per_device_day p
        WHERE p.local_day = days.day
      ), '{}'::jsonb)::text
    ELSE
      jsonb_build_object(
        'All outlets',
        round(COALESCE((
          SELECT sum(p.kwh)
          FROM per_device_day p
          WHERE p.local_day = days.day
        ), 0)::numeric, 2)
      )::text
  END AS "Series"
FROM days
CROSS JOIN bounds
ORDER BY days.day
