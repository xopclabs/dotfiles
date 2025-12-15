{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.glance;
    piholeCfg = config.homelab.pihole_unbound;

    # Build glance from dev branch with passwordless Pi-hole v6 support (PR #783)
    glanceCustom = pkgs.glance.overrideAttrs (oldAttrs: rec {
        version = "0.8.4-dev-if-you-are-reading-this-in-the-future-please-remove-this-override-they-probably-have-released-a-new-version";
        src = pkgs.fetchFromGitHub {
            owner = "glanceapp";
            repo = "glance";
            rev = "784bf5342570af94e62238c4f4a7b542d1853077";
            hash = "sha256-vXdKSz89kSOb/gIwcq+vpRSYoHnKCWjQNodzLwsl/vs=";
        };
        vendorHash = "sha256-g5ZZneJ1g5rs3PJcNP+bi+SuRyZIXBPBjWiKt7wbe5I=";
    });
    
    # Group services by their group attribute
    groupedServices = groupBy (s: s.group) cfg.services;
    
    # Get all group names
    allGroups = attrNames groupedServices;
    
    # Order groups: first by groupOrder, then remaining groups alphabetically
    orderedGroups = 
        (filter (g: hasAttr g groupedServices) cfg.groupOrder) ++
        (filter (g: !(elem g cfg.groupOrder)) (sort lessThan allGroups));
    
    # Sort services within a group by priority (lower = first)
    sortByPriority = services: sort (a: b: a.priority < b.priority) services;
    
    # Generate monitor widget for a group of services
    mkMonitorWidget = group: {
        type = "monitor";
        cache = "1m";
        title = group;
        sites = map (s: {
            title = s.title;
            url = "https://${s.subdomain}.\${DOMAIN}";
            icon = s.icon;
        } // optionalAttrs (s.altStatusCodes != []) {
            alt-status-codes = s.altStatusCodes;
        }) (sortByPriority groupedServices.${group});
    };
    
    # Generate all monitor widgets in specified order
    monitorWidgets = map mkMonitorWidget orderedGroups;
in
{
    options.homelab.glance = {
        enable = mkEnableOption "Glance self-hosted dashboard";

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for Glance dashboard";
        };

        port = mkOption {
            type = types.int;
            default = 8090;
            description = "Port for Glance web interface";
        };

        proxy = mkOption {
            type = types.bool;
            default = true;
            description = "Route Glance through SOCKS5 proxy";
        };

        groupOrder = mkOption {
            type = types.listOf types.str;
            default = [ "Services" "*arr" "Other" ];
            description = "Order in which service groups appear on the dashboard";
        };

        theme = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable custom Nord theme";
            };
            # HSL colors for Glance theme config (required format)
            backgroundColor = mkOption {
                type = types.str;
                default = "220 16% 22%"; # Nord base00
                description = "Background color in HSL format (without 'hsl()' wrapper)";
            };
            primaryColor = mkOption {
                type = types.str;
                default = "210 34% 63%"; # Nord base0D
                description = "Primary/accent color in HSL format";
            };
            positiveColor = mkOption {
                type = types.str;
                default = "92 28% 65%"; # Nord base0B
                description = "Positive/success color in HSL format";
            };
            negativeColor = mkOption {
                type = types.str;
                default = "354 42% 56%"; # Nord base08
                description = "Negative/error color in HSL format";
            };
        };

        weather = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable weather widget (requires WEATHER_LOCATION in glance sops secret)";
            };
        };

        clock = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable clock widget (uses TZ_1, TZ_1_LABEL, TZ_2, TZ_2_LABEL, etc. from sops secret)";
            };
            count = mkOption {
                type = types.int;
                default = 4;
                description = "Number of timezones to display (uses TZ_1, TZ_1_LABEL, TZ_2, TZ_2_LABEL, etc. from sops secret)";
            };
        };

        markets = {
            enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable markets widget (uses MARKET_1_SYMBOL, MARKET_1_NAME, etc. from sops secret)";
            };
            count = mkOption {
                type = types.int;
                default = 4;
                description = "Number of markets to display";
            };
        };

        services = mkOption {
            type = types.listOf (types.submodule {
                options = {
                    title = mkOption {
                        type = types.str;
                        description = "Display name of the service";
                    };
                    subdomain = mkOption {
                        type = types.str;
                        description = "Subdomain of the service (without domain)";
                    };
                    icon = mkOption {
                        type = types.str;
                        description = "Icon for the service (e.g., 'si:jellyfin')";
                    };
                    group = mkOption {
                        type = types.str;
                        description = "Group to categorize the service (e.g., 'Media', 'Arr Stack')";
                    };
                    altStatusCodes = mkOption {
                        type = types.listOf types.int;
                        default = [];
                        description = "Alternative HTTP status codes to consider as 'up' (e.g., [401, 403] for auth-protected services)";
                    };
                    priority = mkOption {
                        type = types.int;
                        default = 1000;
                        description = "Display priority within group (lower = first, default 1000)";
                    };
                };
            });
            default = [];
            description = "List of services to monitor on the dashboard";
        };

        bookmarks = mkOption {
            type = types.listOf (types.submodule {
                options = {
                    title = mkOption {
                        type = types.str;
                        description = "Group title";
                    };
                    links = mkOption {
                        type = types.listOf (types.submodule {
                            options = {
                                title = mkOption {
                                    type = types.str;
                                    description = "Link title";
                                };
                                url = mkOption {
                                    type = types.str;
                                    description = "Link URL";
                                };
                            };
                        });
                        default = [];
                        description = "Links in this group";
                    };
                };
            });
            default = [];
            description = "Bookmark groups to display";
        };
    };

    config = mkIf cfg.enable {
        sops.secrets.glance = {
            sopsFile = ../../secrets/shared/selfhost.yaml;
        };

        services.glance = {
            enable = true;
            # TODO: Remove this override once it's released
            package = glanceCustom;
            environmentFile = config.sops.secrets.glance.path;
            settings = {
                server.port = cfg.port;
                theme = mkIf cfg.theme.enable {
                    background-color = "hsl(${cfg.theme.backgroundColor})";
                    primary-color = "hsl(${cfg.theme.primaryColor})";
                    positive-color = "hsl(${cfg.theme.positiveColor})";
                    negative-color = "hsl(${cfg.theme.negativeColor})";
                    contrast-multiplier = 1.1;
                    text-saturation-multiplier = 0.5;
                };
                pages = [
                    {
                        name = "Startpage";
                        hide-desktop-navigation = true;
                        columns = [
                            # Left column: clock, calendar, to-do
                            {
                                size = "small";
                                widgets = (optional cfg.clock.enable {
                                    type = "clock";
                                    hour-format = "24h";
                                    # Timezones from sops secret via environment variables
                                    timezones = map (n: {
                                        timezone = "\${TZ_${toString n}}";
                                        label = "\${TZ_${toString n}_LABEL}";
                                    }) (range 1 cfg.clock.count);
                                }) ++ [
                                    { type = "calendar"; }
                                    { type = "to-do"; }
                                ];
                            }
                            # Center column: search, monitors, stats, bookmarks
                            {
                                size = "full";
                                widgets = [
                                    {
                                        type = "search";
                                        autofocus = true;
                                    }
                                ] ++ monitorWidgets ++ [
                                    # Server stats and DNS stats side by side
                                    {
                                        type = "split-column";
                                        widgets = [
                                            { 
                                                type = "server-stats"; 
                                                servers = [
                                                    {
                                                        type = "local";
                                                        name = "homelab";
                                                        hide-swap = true;
                                                        hide-mountpoints-by-default = true;
                                                        mountpoints = {
                                                            "/".hide = false;
                                                            "/mnt/raid_pool".hide = false;
                                                            "/mnt/backup_pool".hide = false;
                                                        };
                                                    }
                                                ];
                                            }
                                        ] ++ (optional piholeCfg.enable {
                                            type = "dns-stats";
                                            service = "pihole-v6";
                                            url = "https://${piholeCfg.pihole.subdomain}.\${DOMAIN}";
                                        });
                                    }
                                ] ++ (optional (cfg.bookmarks != []) {
                                    type = "bookmarks";
                                    groups = cfg.bookmarks;
                                });
                            }
                            # Right column: weather, markets
                            {
                                size = "small";
                                widgets = (optional cfg.weather.enable {
                                    type = "weather";
                                    hour-format = "24h";
                                    # Location from sops secret via environment variable
                                    location = "\${WEATHER_LOCATION}";
                                }) ++ (optional cfg.markets.enable {
                                    type = "markets";
                                    # Markets from sops secret via environment variables
                                    markets = map (n: {
                                        symbol = "\${MARKET_${toString n}_SYMBOL}";
                                        name = "\${MARKET_${toString n}_NAME}";
                                    }) (range 1 cfg.markets.count);
                                });
                            }
                        ];
                    }
                ];
            };
        };

        # Add traefik secret for DOMAIN variable + proxy settings
        systemd.services.glance = {
            serviceConfig.EnvironmentFile = mkIf config.homelab.traefik.enable [
                config.sops.secrets."traefik/env".path
            ];
        } // optionalAttrs cfg.proxy {
            environment = {
                HTTP_PROXY = "socks5://127.0.0.1:10808";
                HTTPS_PROXY = "socks5://127.0.0.1:10808";
                NO_PROXY = "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,localhost";
            };
        };

        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "glance";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:${toString cfg.port}";
            }
        ];
    };
}
