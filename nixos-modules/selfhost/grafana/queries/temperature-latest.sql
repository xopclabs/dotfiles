SELECT COALESCE(measured_at, received_at) AS time,
       (payload->'scd41'->>'temperature_c')::double precision AS value
FROM mqtt_messages
WHERE topic = 'apartment/room/air-quality'
  AND payload->'scd41' ? 'temperature_c'
ORDER BY COALESCE(measured_at, received_at) DESC
LIMIT 1
