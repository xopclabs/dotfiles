{ config }:

let
    queries = import ../../../../../nixos-modules/selfhost/grafana/queries/queries.nix {
        timezone = "@timezone@";
        baselineDays = 30;
        outletBreakdown = true;
    };
in
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
            sql = queries."co2-history";
            unit = " ppm";
            series = [{ alias = "CO₂"; field = "value"; }];
        };
        temperature = {
            sql = queries."temperature-history";
            unit = " °C";
            axis_decimals = 1;
            series = [{ alias = "Room"; field = "value"; }];
        };
        power = {
            sql = queries."active-power";
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
            sql = queries."humidity-latest";
            format = "time_series";
            value_format = "%.0f%%";
            thresholds = [{ color = "blue"; }];
        };
        prior_avg_power = {
            sql = queries."energy-baseline";
            format = "table";
            range = "today";
            value_format = "%.2f kWh";
            thresholds = [{ color = "blue"; }];
        };
        today_power = {
            sql = queries."energy-selected";
            format = "table";
            range = "today";
            value_format = "%.2f kWh";
            thresholds = [{ color = "blue"; }];
        };
    };
}
