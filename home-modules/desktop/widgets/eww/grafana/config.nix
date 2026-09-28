{ config }:

{
    url_prefix = "https://grafana.vm.local.";
    domain_file = config.sops.secrets."eww/grafana-domain".path;
    token_file = config.sops.secrets."eww/grafana-token".path;
    datasource_uid = "telemetry-postgres";
    periods = [
        { label = "1h"; ms = 60 * 60 * 1000; }
        { label = "6h"; ms = 6 * 60 * 60 * 1000; }
        { label = "24h"; ms = 24 * 60 * 60 * 1000; }
        { label = "7d"; ms = 7 * 24 * 60 * 60 * 1000; }
    ];
    charts = {
        co2 = {
            sql = ''
                WITH samples AS (
                  SELECT COALESCE(measured_at, received_at) AS sample_time, payload
                  FROM mqtt_messages WHERE topic = 'apartment/room/air-quality'
                )
                SELECT $__timeGroupAlias(sample_time, $__interval),
                       avg((payload->>'co2_ppm')::double precision) AS value
                FROM samples
                WHERE $__timeFilter(sample_time)
                  AND payload ? 'co2_ppm'
                GROUP BY 1 ORDER BY 1
            '';
            unit = " ppm";
            series = [{ alias = "CO₂"; field = "value"; }];
        };
        temperature = {
            sql = ''
                WITH samples AS (
                  SELECT COALESCE(measured_at, received_at) AS sample_time, payload
                  FROM mqtt_messages WHERE topic = 'apartment/room/air-quality'
                )
                SELECT $__timeGroupAlias(sample_time, $__interval),
                       avg((payload->'scd41'->>'temperature_c')::double precision) AS value
                FROM samples
                WHERE $__timeFilter(sample_time)
                  AND payload->'scd41' ? 'temperature_c'
                GROUP BY 1 ORDER BY 1
            '';
            unit = " °C";
            axis_decimals = 1;
            series = [{ alias = "Room"; field = "value"; }];
        };
        power = {
            sql = ''
                WITH per_device AS (
                    SELECT $__timeGroupAlias(received_at, $__interval),
                           split_part(topic, '/', 3) AS device,
                           avg((payload->>'apower')::double precision) AS watts
                    FROM mqtt_messages
                    WHERE $__timeFilter(received_at)
                      AND topic LIKE 'apartment/%/%/status/switch:0'
                      AND payload ? 'apower'
                    GROUP BY 1, 2
                )
                SELECT time, device AS metric, sum(watts) AS value
                FROM per_device
                GROUP BY 1, 2 ORDER BY 1, 2
            '';
            unit = " W";
            axis_from_zero = true;
            series = [
                { alias = "AC"; field = "ac"; }
                { alias = "PC"; field = "pc"; }
            ];
        };
    };
    values = {
        humidity = {
            sql = ''
                SELECT received_at AS time,
                       (payload->'scd41'->>'humidity_pct')::double precision AS value
                FROM mqtt_messages
                WHERE topic = 'apartment/room/air-quality'
                  AND payload->'scd41' ? 'humidity_pct'
                ORDER BY received_at DESC LIMIT 1
            '';
            format = "time_series";
            value_format = "%.0f%%";
            thresholds = [{ color = "blue"; }];
        };
        prior_avg_power = {
            # Same-day-to-this-time baseline from shelly-power.json (30 prior days).
            sql = ''
                WITH bounds AS (
                  SELECT $__timeFrom()::timestamptz AS start_at,
                         $__timeTo()::timestamptz AS end_at
                ), selected_topics AS (
                  SELECT topic
                  FROM mqtt_messages, bounds
                  WHERE received_at >= bounds.start_at AND received_at <= bounds.end_at
                    AND topic LIKE 'apartment/%/%/status/switch:0'
                    AND payload->'aenergy'->>'total' IS NOT NULL
                  GROUP BY topic HAVING count(*) >= 2
                ), windows AS (
                  SELECT n,
                         ((b.start_at AT TIME ZONE 'Europe/Madrid') - n * interval '1 day')
                           AT TIME ZONE 'Europe/Madrid' AS start_at,
                         ((b.end_at AT TIME ZONE 'Europe/Madrid') - n * interval '1 day')
                           AT TIME ZONE 'Europe/Madrid' AS end_at
                  FROM bounds b CROSS JOIN generate_series(1, 30) AS days(n)
                ), covered_device AS (
                  SELECT w.n,
                         GREATEST(last_sample.total - first_sample.total, 0) / 1000.0 AS kwh
                  FROM windows w CROSS JOIN selected_topics t
                  JOIN LATERAL (
                    SELECT received_at, (payload->'aenergy'->>'total')::double precision AS total
                    FROM mqtt_messages
                    WHERE topic = t.topic AND received_at >= w.start_at
                      AND received_at <= w.start_at + interval '15 minutes'
                      AND payload->'aenergy'->>'total' IS NOT NULL
                    ORDER BY received_at ASC LIMIT 1
                  ) first_sample ON true
                  JOIN LATERAL (
                    SELECT received_at, (payload->'aenergy'->>'total')::double precision AS total
                    FROM mqtt_messages
                    WHERE topic = t.topic AND received_at >= w.end_at - interval '15 minutes'
                      AND received_at <= w.end_at
                      AND payload->'aenergy'->>'total' IS NOT NULL
                    ORDER BY received_at DESC LIMIT 1
                  ) last_sample ON true
                  WHERE first_sample.received_at < last_sample.received_at
                ), complete_windows AS (
                  SELECT n, sum(kwh) AS kwh
                  FROM covered_device
                  GROUP BY n
                  HAVING count(*) = (SELECT count(*) FROM selected_topics)
                )
                SELECT avg(kwh) AS "Prior avg" FROM complete_windows
            '';
            format = "table";
            range = "today";
            value_format = "%.2f kWh";
            thresholds = [{ color = "blue"; }];
        };
        today_power = {
            sql = ''
                WITH per_device AS (
                    SELECT split_part(topic, '/', 3) AS device,
                           (max((payload->'aenergy'->>'total')::double precision)
                            - min((payload->'aenergy'->>'total')::double precision)) / 1000.0 AS kwh
                    FROM mqtt_messages
                    WHERE $__timeFilter(received_at)
                      AND topic LIKE 'apartment/%/%/status/switch:0'
                      AND payload ? 'aenergy'
                    GROUP BY 1
                )
                SELECT COALESCE(sum(GREATEST(kwh, 0)), 0) AS "Selected" FROM per_device
            '';
            format = "table";
            range = "today";
            value_format = "%.2f kWh";
            thresholds = [{ color = "blue"; }];
        };
    };
}
