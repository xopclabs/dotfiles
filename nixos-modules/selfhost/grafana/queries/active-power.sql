WITH samples AS (
  SELECT CASE WHEN measured_at < received_at - interval '2 minutes'
              THEN measured_at ELSE received_at END AS sample_time, topic, payload
  FROM mqtt_messages
), per_device AS (
  SELECT
    $__timeGroupAlias(sample_time, $__interval),
    split_part(topic, '/', 3) AS device,
    avg((payload->>'apower')::double precision) AS watts
  FROM samples
  WHERE $__timeFilter(sample_time)
    AND topic LIKE 'apartment/%/%/status/switch:0'
    AND payload ? 'apower'
  GROUP BY 1, 2
)
SELECT
  time,
  CASE WHEN @outletBreakdown@ THEN device ELSE 'All outlets' END AS metric,
  sum(watts) AS value
FROM per_device
GROUP BY 1, 2
ORDER BY 1, 2
