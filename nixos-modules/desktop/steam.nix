{ config, lib, pkgs, inputs, ... }:

with lib;
let
    cfg = config.desktop.steam;
    startSteamGamescope = pkgs.writeShellScriptBin "start-gamescope-session" ''
        mkdir -p "$HOME/.cache"
        gamescope=/run/wrappers/bin/gamescope
        if [ ! -x "$gamescope" ]; then
            gamescope=${pkgs.gamescope}/bin/gamescope
        fi
        echo "Shutting down any desktop Steam instance before starting Steam under gamescope" > "$HOME/.cache/start-gamescope-session.log"
        ${pkgs.coreutils}/bin/timeout 10s ${pkgs.steam}/bin/steam -shutdown >> "$HOME/.cache/start-gamescope-session.log" 2>&1 || true
        ${pkgs.coreutils}/bin/sleep 2
        echo "Starting Steam under gamescope: $gamescope --steam -f -- ${pkgs.steam}/bin/steam -tenfoot -pipewire-dmabuf $*" >> "$HOME/.cache/start-gamescope-session.log"
        exec "$gamescope" --steam -f -- ${pkgs.steam}/bin/steam -tenfoot -pipewire-dmabuf "$@" >> "$HOME/.cache/start-gamescope-session.log" 2>&1
    '';
    switchToGamescope = pkgs.writeShellScriptBin "switch-to-gamescope-session" ''
        ${pkgs.systemd}/bin/systemctl --user import-environment PATH XDG_CURRENT_DESKTOP XDG_SESSION_TYPE NIRI_SOCKET
        ${pkgs.systemd}/bin/systemctl --user unset-environment DISPLAY WAYLAND_DISPLAY XAUTHORITY
        ${pkgs.systemd}/bin/systemd-run --user --collect --unit=switch-to-gamescope-session ${pkgs.bash}/bin/bash -lc '
            sleep 1
            exec env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY ${pkgs.gamescope-session}/bin/start-gamescope-session
        '
        if [ -n "''${NIRI_SOCKET:-}" ]; then
            ${pkgs.niri}/bin/niri msg action quit --skip-confirmation || true
        fi
    '';
in
{
    options.desktop.steam = {
        enable = mkEnableOption "Steam and gaming configuration";

        jovian = {
            enable = mkEnableOption "Jovian NixOS Steam Deck configuration";

            autoStart = mkOption {
                type = types.bool;
                default = true;
                description = "Auto-start Steam on boot";
            };

            desktopSession = mkOption {
                type = types.nullOr types.str;
                default = "niri";
                description = "Desktop session to use when Jovian autostart is enabled";
            };

            steamDeck = {
                enable = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Enable Steam Deck-specific Jovian device and SteamOS settings";
                };
            };

            deckyLoader = {
                enable = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Enable Decky Loader for Steam Deck plugins";
                };

                user = mkOption {
                    type = types.str;
                    default = "decky";
                    description = "User for Decky Loader";
                };
            };
        };

        gamescopeSession = {
            enable = mkOption {
                type = types.bool;
                default = false;
                description = "Enable the regular NixOS Steam gamescope session";
            };
        };

        extraPackages = mkOption {
            type = types.bool;
            default = true;
            description = "Install extra gaming packages (protontricks, protonup-ng)";
        };

        hardware = {
            xoneSupport = mkOption {
                type = types.bool;
                default = true;
                description = "Enable Xbox One controller support";
            };

            joyconSupport = mkOption {
                type = types.bool;
                default = true;
                description = "Enable Nintendo Joy-Con support";
            };

            trackpadDesktop = mkOption {
                type = types.bool;
                default = true;
                description = "Enable trackpad support in desktop mode";
            };
        };
    };

    config = mkIf cfg.enable {
        programs.steam = {
            enable = true;
            gamescopeSession.enable = cfg.gamescopeSession.enable;
        };

        # Jovian NixOS configuration
        jovian = mkIf cfg.jovian.enable {
            steam = {
                enable = true;
                autoStart = cfg.jovian.autoStart;
                desktopSession = cfg.jovian.desktopSession;
                user = config.metadata.user;
            };

            devices.steamdeck.enable = cfg.jovian.steamDeck.enable;
            steamos.useSteamOSConfig = cfg.jovian.steamDeck.enable;

            decky-loader = mkIf cfg.jovian.deckyLoader.enable {
                enable = true;
                user = cfg.jovian.deckyLoader.user;
            };
        };

        services.displayManager.defaultSession = mkIf (!cfg.jovian.autoStart && cfg.jovian.desktopSession != null) cfg.jovian.desktopSession;

        # Kernel from Jovian's own nixpkgs pin, not ours. The module overlay
        # otherwise rebuilds linux_jovian against host stdenv on every unstable bump.
        boot.kernelPackages = mkIf (cfg.jovian.enable && cfg.jovian.steamDeck.enable) (
            mkForce inputs.jovian.legacyPackages.${pkgs.stdenv.hostPlatform.system}.linuxPackages_jovian
        );

        nix.settings = mkIf cfg.jovian.enable {
            substituters = [
                "https://jovian.cachix.org"
                "https://chaotic-nyx.cachix.org"
            ];
            trusted-public-keys = [
                "jovian.cachix.org-1:8Vq4Txku6VZIRhYrHYki3Ab9XHJRoWmdYqMqj4rB/Uc="
                "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
            ];
        };

        # Prevent Gamescope from trying to nest into the previous desktop session.
        systemd.user.services.gamescope-session.serviceConfig = mkIf cfg.jovian.enable {
            ExecStart = mkForce [
                ""
                "${pkgs.coreutils}/bin/env -u DISPLAY -u WAYLAND_DISPLAY -u XAUTHORITY ${pkgs.gamescope-session}/lib/steamos/gamescope-session"
            ];
            TimeoutStartSec = 45;
        };

        # Set up ownership for Steam and its directories
        systemd.tmpfiles.rules = [
            "d /home/${config.metadata.user}/.local 0755 ${config.metadata.user} users -"
            "d /home/${config.metadata.user}/.local/share 0755 ${config.metadata.user} users -"
            "Z /home/${config.metadata.user}/.local/share - ${config.metadata.user} users -"
        ];

        # Extra gaming packages
        environment.systemPackages = mkMerge [
            (mkIf cfg.extraPackages (with pkgs; [
                mangohud
                protontricks
                protonup-ng
            ]))
            (mkIf (cfg.gamescopeSession.enable && !cfg.jovian.enable) [
                startSteamGamescope
            ])
            (mkIf cfg.jovian.enable [
                switchToGamescope
            ])
        ];

        hardware.graphics = mkIf cfg.extraPackages {
            extraPackages = [ pkgs.mangohud ];
            extraPackages32 = [ pkgs.pkgsi686Linux.mangohud ];
        };

        # Hardware support
        hardware.xone.enable = mkIf cfg.hardware.xoneSupport true;
        services.joycond.enable = mkIf cfg.hardware.joyconSupport true;
        programs.steam.extest.enable = mkIf cfg.hardware.trackpadDesktop true;

        # Add user to input group if trackpad support is enabled
        users.users.${config.metadata.user}.extraGroups = mkIf cfg.hardware.trackpadDesktop [ "input" ];
    };
}

