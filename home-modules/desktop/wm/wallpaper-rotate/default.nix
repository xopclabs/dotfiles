{ pkgs, lib, config, ... }:

with lib;
let
    cfg = config.modules.desktop.wm.wallpaperRotate;
    hardwareCfg = config.metadata.hardware;
    internal = hardwareCfg.monitors.internal;

    monitorsJson = builtins.toJSON {
        internal = if internal != null then internal.name else null;
    };

    fallback = "${config.home.homeDirectory}/.config/wallpaper/nord.png";
    domainFile = "${config.xdg.configHome}/sops-nix/secrets/wallpaper-rotate/domain";
in {
    options.modules.desktop.wm.wallpaperRotate = {
        enable = mkEnableOption "daily generated wallpapers from the VPS grid service";

        subdomain = mkOption {
            type = types.str;
            default = "wallpaper";
            description = "Public subdomain of the generator (wallpaper.$DOMAIN).";
        };

        palette = mkOption {
            type = types.str;
            default = "nord";
            description = "Palette name sent in every POST /grid body.";
        };

        rerollBind = mkOption {
            type = types.nullOr types.str;
            default = "$mod SHIFT, W";
            description = "Hyprland bind prefix for reroll (null to skip).";
        };
    };

    config = mkIf cfg.enable (let
        wallpaper-rotate = pkgs.writeShellScriptBin "wallpaper-rotate" ''
            export PATH=${lib.makeBinPath [
                pkgs.coreutils
                pkgs.curl
                pkgs.findutils
                pkgs.gnugrep
                pkgs.hyprland
                pkgs.jq
                pkgs.socat
                pkgs.util-linux
                pkgs.awww
            ]}:$PATH
            ${builtins.replaceStrings
                [
                    "@HOST@"
                    "@MONITORS_JSON@"
                    "@DOMAIN_FILE@"
                    "@SUBDOMAIN@"
                    "@PALETTE@"
                    "@FALLBACK@"
                ]
                [
                    config.metadata.hostName
                    monitorsJson
                    domainFile
                    cfg.subdomain
                    cfg.palette
                    fallback
                ]
                (builtins.readFile ./wallpaper-rotate)
            }
        '';
    in {
        assertions = [
            {
                assertion = config.modules.desktop.wm.hyprland.enable;
                message = "modules.desktop.wm.wallpaperRotate requires Hyprland (logical size and output events).";
            }
        ];

        sops.secrets."wallpaper-rotate/domain" = {
            sopsFile = ../../../../secrets/shared/selfhost.yaml;
            key = "domain";
            path = domainFile;
        };

        home.packages = [ wallpaper-rotate ];

        wayland.windowManager.hyprland.settings.bind = mkIf (
            config.modules.desktop.wm.hyprland.enable && cfg.rerollBind != null
        ) [
            "${cfg.rerollBind}, exec, ${wallpaper-rotate}/bin/wallpaper-rotate reroll"
        ];

        systemd.user.services.awww = {
            Unit = {
                Description = "awww wallpaper daemon";
                After = [ "graphical-session.target" ];
                PartOf = [ "graphical-session.target" ];
            };
            Service = {
                ExecStart = "${pkgs.awww}/bin/awww-daemon";
                Restart = "on-failure";
                RestartSec = 1;
            };
            Install.WantedBy = [ "graphical-session.target" ];
        };

        systemd.user.services.wallpaper-rotate = {
            Unit = {
                Description = "Apply generated wallpapers to current outputs";
                After = [ "graphical-session.target" "awww.service" "sops-nix.service" ];
                Wants = [ "awww.service" ];
            };
            Service = {
                Type = "oneshot";
                ExecStart = "${wallpaper-rotate}/bin/wallpaper-rotate apply";
            };
        };

        systemd.user.timers.wallpaper-rotate = {
            Unit = {
                Description = "Midnight wallpaper rotation";
            };
            Timer = {
                OnCalendar = "*-*-* 00:00:00";
                Persistent = true;
                Unit = "wallpaper-rotate.service";
            };
            Install.WantedBy = [ "timers.target" ];
        };

        systemd.user.services.wallpaper-rotate-watch = {
            Unit = {
                Description = "Re-apply generated wallpapers when Hyprland adds an output";
                After = [ "graphical-session.target" "awww.service" "sops-nix.service" ];
                Wants = [ "awww.service" ];
                PartOf = [ "graphical-session.target" ];
            };
            Service = {
                ExecStart = "${wallpaper-rotate}/bin/wallpaper-rotate watch";
                Restart = "always";
                RestartSec = 1;
            };
            Install.WantedBy = [ "graphical-session.target" ];
        };
    });
}
