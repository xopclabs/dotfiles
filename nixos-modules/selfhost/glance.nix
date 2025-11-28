{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.glance;
    
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
        services.glance = {
            enable = true;
            # Reuse traefik secret which contains DOMAIN variable
            environmentFile = mkIf config.homelab.traefik.enable 
                config.sops.secrets.traefik.path;
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
                        width = "slim";
                        hide-desktop-navigation = true;
                        center-vertically = true;
                        columns = [
                            {
                                size = "full";
                                widgets = [
                                    {
                                        type = "search";
                                        autofocus = true;
                                    }
                                ] ++ monitorWidgets ++ (optional (cfg.bookmarks != []) {
                                    type = "bookmarks";
                                    groups = cfg.bookmarks;
                                });
                            }
                        ];
                    }
                ];
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
