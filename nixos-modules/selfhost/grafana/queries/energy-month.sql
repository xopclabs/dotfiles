WITH per_device AS (
  SELECT
    split_part(topic, '/', 3) AS device,
    (max((payload->'aenergy'->>'total')::double precision)
      - min((payload->'aenergy'->>'total')::double precision)) / 1000.0 AS kwh
  FROM mqtt_messages
  WHERE COALESCE(measured_at, received_at) >= date_trunc('month', CURRENT_TIMESTAMP)
    AND COALESCE(measured_at, received_at) <= CURRENT_TIMESTAMP
    AND topic LIKE 'apartment/%/%/status/switch:0'
    AND payload ? 'aenergy'
  GROUP BY 1
)
SELECT COALESCE(sum(GREATEST(kwh, 0)), 0) AS "MTD" FROM per_device
