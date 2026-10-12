-- A qualifying run needs distinct readings spanning ten minutes. A reading
-- below 1000 or a reporting gap of 30 minutes breaks the qualifying run.
-- Once qualified, only a subsequent reading below 800 clears the episode.
WITH readings AS (
    SELECT received_at, (payload->>'co2_ppm')::double precision AS ppm,
        lag(received_at) OVER (ORDER BY received_at, id) AS previous_at
    FROM mqtt_messages
    WHERE topic = 'apartment/room/air-quality'
      AND NOT retained
      AND payload ? 'co2_ppm'
      AND received_at >= COALESCE((
          SELECT received_at FROM mqtt_messages
          WHERE topic = 'apartment/room/air-quality' AND NOT retained
            AND payload ? 'co2_ppm'
            AND (payload->>'co2_ppm')::double precision < 800
          ORDER BY received_at DESC, id DESC LIMIT 1
      ), '-infinity'::timestamptz)
), runs AS (
    SELECT *, sum(CASE WHEN ppm < 1000 OR previous_at IS NULL
        OR received_at - previous_at >= interval '30 minutes'
        THEN 1 ELSE 0 END) OVER (ORDER BY received_at) AS run
    FROM readings
), qualified AS (
    SELECT min(received_at) AS started_at, max(received_at) AS last_high_at
    FROM runs
    WHERE ppm >= 1000
    GROUP BY run
    HAVING count(DISTINCT received_at) >= 2
        AND max(received_at) - min(received_at) >= interval '10 minutes'
), latest_qualified AS (
    SELECT last_high_at FROM qualified ORDER BY last_high_at DESC LIMIT 1
), reset AS (
    SELECT max(received_at) AS reset_at FROM readings, latest_qualified
    WHERE ppm < 800 AND received_at < latest_qualified.last_high_at
), episode AS (
    SELECT min(started_at) AS started_at, max(last_high_at) AS last_high_at
    FROM qualified, reset
    WHERE reset.reset_at IS NULL OR started_at > reset.reset_at
), recovery AS (
    SELECT min(received_at) AS ended_at
    FROM readings, episode
    WHERE received_at > episode.last_high_at AND ppm < 800
)
SELECT CASE WHEN episode.started_at IS NOT NULL AND recovery.ended_at IS NULL
        THEN 1 ELSE 0 END::double precision AS state,
    COALESCE(EXTRACT(EPOCH FROM (COALESCE(recovery.ended_at, now())
        - episode.started_at)) / 60, 0)::double precision AS minutes
FROM recovery LEFT JOIN episode ON true;
