SELECT COALESCE(measured_at, received_at) AS time,
       (payload->>'co2_ppm')::double precision AS value
FROM mqtt_messages
WHERE topic = 'apartment/room/air-quality'
  AND payload ? 'co2_ppm'
ORDER BY COALESCE(measured_at, received_at) DESC
LIMIT 1
