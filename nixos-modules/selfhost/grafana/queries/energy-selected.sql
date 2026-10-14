WITH samples AS (
  SELECT COALESCE(measured_at, received_at) AS sample_time, topic, payload
  FROM mqtt_messages
), selected_device AS (
  SELECT split_part(topic, '/', 3) AS device,
         GREATEST(max((payload->'aenergy'->>'total')::double precision)
           - min((payload->'aenergy'->>'total')::double precision), 0) / 1000.0 AS kwh
  FROM samples
  WHERE $__timeFilter(sample_time)
    AND topic LIKE 'apartment/%/%/status/switch:0'
    AND payload ? 'aenergy'
    AND payload->'aenergy'->>'total' IS NOT NULL
  GROUP BY 1
  HAVING count(*) >= 2
)
SELECT sum(kwh) AS "Selected" FROM selected_device
