{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.fail2ban;

    configFormat = pkgs.formats.ini { };

    traefikJailOptions = {
        host = mkOption {
            type = types.str;
            example = "vaultwarden";
            description = ''
                Traefik route subdomain prefix. Matches RequestHost values like
                `vaultwarden.example.com` via a `host.` prefix in the filter.
            '';
        };

        paths = mkOption {
            type = types.listOf types.str;
            default = [];
            example = [ "/identity/connect/token" ];
            description = "Request paths that must match exactly.";
        };

        pathPrefixes = mkOption {
            type = types.listOf types.str;
            default = [];
            example = [ "/admin" ];
            description = ''
                Request path prefixes. `/admin` also matches `/admin/` and
                `/admin/users`.
            '';
        };

        methods = mkOption {
            type = types.nullOr (types.listOf types.str);
            default = null;
            example = [ "POST" ];
            description = "HTTP methods to match. Null matches any method.";
        };

        statusCodes = mkOption {
            type = types.listOf types.int;
            default = [ 401 403 ];
            example = [ 400 401 ];
            description = "Downstream HTTP status codes that count as failures.";
        };
    };

    jailOptions = {
        name = mkOption {
            type = types.str;
            description = "Fail2ban jail name (also used as the filter name).";
        };

        enabled = mkOption {
            type = types.bool;
            default = true;
            description = "Whether this jail is enabled.";
        };

        traefik = mkOption {
            type = types.nullOr (types.submodule { options = traefikJailOptions; });
            default = null;
            description = ''
                Build a filter from Traefik JSON access logs. Intended for
                publicly exposed services behind Traefik.
            '';
        };

        filter = mkOption {
            type = types.nullOr configFormat.type;
            default = null;
            description = ''
                Custom fail2ban filter definition. Use when `traefik` is null.
                The attrset is written to `filter.d/<name>.conf`.
            '';
        };

        settings = mkOption {
            type = types.attrsOf types.anything;
            default = { };
            description = "Additional jail.local settings for this jail.";
        };
    };

    mkPathPattern = paths: pathPrefixes:
        let
            exact = map (p: lib.escapeRegex p) paths;
            prefixes = map (p: "${lib.escapeRegex p}[^\"]*") pathPrefixes;
            all = exact ++ prefixes;
        in
        if all == [] then ".*"
        else "(?:${lib.concatStringsSep "|" all})";

    mkTraefikFilter =
        { host, paths, pathPrefixes, methods, statusCodes }:
        let
            hostPat = lib.escapeRegex host;
            pathPat = mkPathPattern paths pathPrefixes;
            statusPat = lib.concatMapStringsSep "|" toString statusCodes;
            methodPat =
                if methods == null then ".*"
                else lib.concatStringsSep "|" (map lib.escapeRegex methods);
            hostReq = ''"RequestHost":"${hostPat}\.'';
            pathReq = ''"RequestPath":"${pathPat}'';
            statusReq = ''"DownstreamStatus":(?:${statusPat})'';
            methodReq =
                if methods == null then ""
                else ''(?:(?!"\}").)*"RequestMethod":"(?:${methodPat})"'';
            mkLines = ipField: [
                ''^\{.*${ipField}${methodReq}(?:(?!"\}").)*${hostReq}(?:(?!"\}").)*${pathReq}(?:(?!"\}").)*${statusReq}''
                ''^\{.*${ipField}(?:(?!"\}").)*${statusReq}(?:(?!"\}").)*${hostReq}(?:(?!"\}").)*${pathReq}${methodReq}''
            ];
        in
        {
            Definition = {
                failregex = lib.concatStringsSep "\n            " (
                    mkLines ''"Cf-Connecting-Ip":\["<HOST>"\]''
                    ++ mkLines ''"ClientHost":"<HOST>"''
                );
                ignoreregex = "";
            };
        };

    defaultTraefikJailSettings = {
        logpath = cfg.traefik.logPath;
        backend = "auto";
        port = "http,https";
        maxretry = cfg.maxretry;
        findtime = cfg.findtime;
        bantime = cfg.bantime;
    };

    mkJailEntry = jail:
        let
            traefikFilter =
                if jail.traefik != null then
                    mkTraefikFilter jail.traefik
                else
                    null;
        in
        nameValuePair jail.name {
            inherit (jail) enabled;
            filter =
                if jail.filter != null then jail.filter
                else traefikFilter;
            settings = defaultTraefikJailSettings // jail.settings;
        };
in
{
    options.homelab.fail2ban = {
        enable = mkEnableOption "Fail2ban intrusion prevention";

        bantime = mkOption {
            type = types.str;
            default = "1h";
            description = "Default ban duration for registered jails.";
        };

        findtime = mkOption {
            type = types.str;
            default = "10m";
            description = "Default observation window for registered jails.";
        };

        maxretry = mkOption {
            type = types.ints.unsigned;
            default = 5;
            description = "Default number of failures before a ban.";
        };

        ignoreIP = mkOption {
            type = types.listOf types.str;
            default = [
                "192.168.0.0/16"
                "10.0.0.0/8"
                "172.16.0.0/12"
            ];
            description = ''
                Addresses that must never be banned. Defaults cover common
                private networks (including WireGuard subnets in 10.0.0.0/8).
            '';
        };

        traefik = {
            logPath = mkOption {
                type = types.str;
                default = "/var/lib/traefik/access.log";
                description = "Traefik access log watched by Traefik-based jails.";
            };
        };

        jails = mkOption {
            type = types.listOf (types.submodule { options = jailOptions; });
            default = [];
            description = ''
                Fail2ban jails contributed by self-hosted services. Each service
                module appends entries here, similar to `homelab.traefik.routes`.
            '';
        };
    };

    config = mkIf cfg.enable {
        assertions = [
            {
                assertion =
                    builtins.all (
                        jail:
                        jail.traefik != null || jail.filter != null
                    ) cfg.jails;
                message = "homelab.fail2ban.jails: each jail needs `traefik` or `filter`.";
            }
            {
                assertion =
                    length cfg.jails == length (lib.unique (map (j: j.name) cfg.jails));
                message = "homelab.fail2ban.jails: jail names must be unique.";
            }
        ];

        services.fail2ban = {
            enable = true;
            inherit (cfg) bantime maxretry;
            ignoreIP = cfg.ignoreIP;
            jails = listToAttrs (map mkJailEntry cfg.jails);
        };
    };
}
