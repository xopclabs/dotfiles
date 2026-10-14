WITH samples AS (
    SELECT COALESCE(measured_at, received_at) AS sample_time, payload
    FROM mqtt_messages
    WHERE topic = 'apartment/room/air-quality'
)
SELECT $__timeGroupAlias(sample_time, $__interval),
       avg((payload->'scd41'->>'humidity_pct')::double precision) AS value
FROM samples
WHERE $__timeFilter(sample_time)
  AND payload->'scd41' ? 'humidity_pct'
GROUP BY 1
ORDER BY 1
