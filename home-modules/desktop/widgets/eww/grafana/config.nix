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
                SELECT $__timeGroupAlias(received_at, $__interval),
                       avg((payload->>'co2_ppm')::double precision) AS value
                FROM mqtt_messages
                WHERE $__timeFilter(received_at)
                  AND topic = 'apartment/room/air-quality'
                  AND payload ? 'co2_ppm'
                GROUP BY 1 ORDER BY 1
            '';
            unit = " ppm";
            series = [{ alias = "CO₂"; field = "value"; }];
        };
        temperature = {
            sql = ''
                SELECT $__timeGroupAlias(received_at, $__interval),
                       avg((payload->'scd41'->>'temperature_c')::double precision) AS value
                FROM mqtt_messages
                WHERE $__timeFilter(received_at)
                  AND topic = 'apartment/room/air-quality'
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
