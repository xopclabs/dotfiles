WITH samples AS (
    SELECT COALESCE(measured_at, received_at) AS sample_time, payload
    FROM mqtt_messages
    WHERE topic = 'apartment/room/air-quality'
)
SELECT $__timeGroupAlias(sample_time, $__interval),
       avg((payload->>'co2_ppm')::double precision) AS value
FROM samples
WHERE $__timeFilter(sample_time)
  AND payload ? 'co2_ppm'
GROUP BY 1
ORDER BY 1
