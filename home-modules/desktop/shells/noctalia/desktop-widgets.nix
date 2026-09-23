{ config, lib, ... }:

let
    cfg = config.modules.desktop.shells.noctalia.desktopWidgets;
    output = "eDP-1";
    grafana = {
        url_prefix = "https://grafana.vm.local.";
        domain_file = config.sops.secrets."noctalia/grafana-domain".path;
        token_file = config.sops.secrets."noctalia/grafana-token".path;
        periods = [
            { label = "1h"; ms = 60 * 60 * 1000; }
            { label = "6h"; ms = 6 * 60 * 60 * 1000; }
            { label = "24h"; ms = 24 * 60 * 60 * 1000; }
            { label = "7d"; ms = 7 * 24 * 60 * 60 * 1000; }
        ];
        charts = {
            co2 = {
                title = "CO₂";
                icon = "lungs-filled";
                title_font_size = 18;
                dashboard_uid = "air-quality";
                panel_id = 4;
                unit = " ppm";
                series = [{ alias = "CO₂"; field = "value"; }];
            };
            temperature = {
                title = "Temperature";
                icon = "temperature";
                title_font_size = 18;
                dashboard_uid = "air-quality";
                panel_id = 5;
                unit = " °C";
                axis_decimals = 1;
                series = [{ alias = "Room"; field = "value"; }];
            };
            power = {
                title = "Active power";
                icon = "plug-filled";
                title_font_size = 18;
                dashboard_uid = "apartment-power";
                panel_id = 1;
                unit = " W";
                axis_from_zero = true;
                replacements."\${outlet_breakdown:raw}" = "true";
                series = [
                    { alias = "AC"; field = "ac"; }
                    { alias = "PC"; field = "pc"; }
                ];
            };
        };
        values = {
            humidity = {
                title = "Humidity";
                icon = "droplet-filled";
                title_align = "center";
                title_font_size = 17;
                dashboard_uid = "air-quality";
                panel_id = 3;
                format = "%.0f%%";
            };
            today_power = {
                title = "Energy";
                icon = "bolt-filled";
                title_align = "center";
                title_font_size = 17;
                dashboard_uid = "apartment-power";
                panel_id = 2;
                range = "today";
                format = "%.2f kWh";
                value_font_size = 30;
            };
        };
    };
in {
    options.modules.desktop.shells.noctalia.desktopWidgets.enable = lib.mkEnableOption "Grafana tiles on the PC internal display";

    config = lib.mkIf cfg.enable {
        sops.secrets = {
            "noctalia/grafana-token" = {
                sopsFile = ../../../../secrets/hosts/pc.yaml;
                key = "grafana/noctalia-token";
            };
            "noctalia/grafana-domain" = {
                sopsFile = ../../../../secrets/shared/selfhost.yaml;
                key = "domain";
            };
        };

        xdg.configFile."noctalia/grafana-widgets.json".text = builtins.toJSON grafana;

        programs.noctalia.settings = {
            plugins = {
                enabled = [ "xopc/grafana" ];
                source = [{
                    name = "local-grafana";
                    kind = "path";
                    location = toString ./plugins;
                    enabled = true;
                }];
            };
            plugin_settings."xopc/grafana".config_file = "${config.xdg.configHome}/noctalia/grafana-widgets.json";
            desktop_widgets = {
                enabled = true;
                widget_order = [ "co2_chart" "temperature_chart" "power_chart" "humidity_value" "today_power" ];
                widget = {
                    co2_chart = {
                        type = "xopc/grafana:co2-chart";
                        inherit output;
                        settings = {
                            background = true;
                            background_color = "surface";
                            background_opacity = 1.0;
                            background_radius = 0.0;
                            background_padding = 0.0;
                        };
                        cx = 280.0;
                        cy = 145.0;
                        box_width = 420.0;
                    };
                    temperature_chart = {
                        type = "xopc/grafana:temperature-chart";
                        inherit output;
                        settings = {
                            background = true;
                            background_color = "surface";
                            background_opacity = 1.0;
                            background_radius = 0.0;
                            background_padding = 0.0;
                        };
                        cx = 725.0;
                        cy = 145.0;
                        box_width = 420.0;
                    };
                    power_chart = {
                        type = "xopc/grafana:power-chart";
                        inherit output;
                        settings = {
                            background = true;
                            background_color = "surface";
                            background_opacity = 1.0;
                            background_radius = 0.0;
                            background_padding = 0.0;
                        };
                        cx = 280.0;
                        cy = 390.0;
                        box_width = 420.0;
                    };
                    humidity_value = {
                        type = "xopc/grafana:humidity-value";
                        inherit output;
                        settings = {
                            background = true;
                            background_color = "surface";
                            background_opacity = 1.0;
                            background_radius = 0.0;
                            background_padding = 0.0;
                        };
                        cx = 615.0;
                        cy = 390.0;
                        box_width = 190.0;
                    };
                    today_power = {
                        type = "xopc/grafana:today-power";
                        inherit output;
                        settings = {
                            background = true;
                            background_color = "surface";
                            background_opacity = 1.0;
                            background_radius = 0.0;
                            background_padding = 0.0;
                        };
                        cx = 835.0;
                        cy = 390.0;
                        box_width = 190.0;
                    };
                };
            };
        };
    };
}
