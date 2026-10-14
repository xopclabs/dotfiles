SELECT COALESCE(measured_at, received_at) AS time,
       (payload->'scd41'->>'humidity_pct')::double precision AS value
FROM mqtt_messages
WHERE topic = 'apartment/room/air-quality'
  AND payload->'scd41' ? 'humidity_pct'
ORDER BY COALESCE(measured_at, received_at) DESC
LIMIT 1
