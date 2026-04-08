{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.syncthing;
    settingsFormat = pkgs.formats.json { };

    folderModule = types.submodule (
        { name, ... }:
        {
            options = {
                enable = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Whether Syncthing should manage this folder entry.";
                };

                path = mkOption {
                    type = types.str;
                    description = "Absolute path to the directory on this host.";
                };

                id = mkOption {
                    type = types.str;
                    default = name;
                    description = ''
                      Folder ID; must match on every device that shares this folder.
                      Defaults to the attribute name (e.g. `folders.music` → id `"music"`).
                    '';
                };

                label = mkOption {
                    type = types.str;
                    default = name;
                    description = "Display label in the Syncthing UI.";
                };

                type = mkOption {
                    type = types.enum [
                        "sendreceive"
                        "sendonly"
                        "receiveonly"
                        "receiveencrypted"
                    ];
                    default = "sendreceive";
                    description = "Syncthing folder mode.";
                };

                devices = mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                    description = ''
                      Keys of entries under `settings.devices` to share this folder with.
                      Add devices there with each peer's ID from *Actions → Show ID* on the other machine.
                    '';
                };
            };
        }
    );

    folderEntries = mapAttrs (
        _: f: {
            inherit (f) enable path id label type devices;
        }
    ) cfg.folders;

    withFolders = recursiveUpdate cfg.settings {
        folders = recursiveUpdate (cfg.settings.folders or { }) folderEntries;
    };

    # Behind Traefik the browser sends Host: <subdomain>… while the GUI listens on 127.0.0.1;
    # Syncthing then shows "Host check error" unless this is set.
    mergedSettings =
        if !cfg.insecureSkipGuiHostCheck then
            withFolders
        else
            recursiveUpdate withFolders {
                gui = recursiveUpdate (withFolders.gui or { }) {
                    insecureSkipHostCheck = true;
                };
            };

    folderMountPaths = map (f: f.path) (
        builtins.attrValues (filterAttrs (_: f: f.enable) cfg.folders)
    );
in
{
    options.homelab.syncthing = {
        enable = mkEnableOption "Syncthing file synchronization";

        openDefaultPorts = mkEnableOption ''
          Open firewall for Syncthing (TCP/UDP 22000, UDP 21027).
          Disable if you only sync over a VPN or use custom listen addresses.
        '';

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for the Syncthing web GUI (Traefik).";
        };

        guiPort = mkOption {
            type = types.port;
            default = 8384;
            description = "Local port for the web GUI (Traefik upstream).";
        };

        insecureSkipGuiHostCheck = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Set Syncthing `gui.insecureSkipHostCheck`. Enable when the web UI is reached via a
              reverse proxy (e.g. Traefik): otherwise Syncthing returns **Host check error** because
              the `Host` header does not match `guiAddress`. Disable only if you use the GUI solely
              at `guiAddress` (e.g. SSH port forward to 127.0.0.1).
            '';
        };

        dataDir = mkOption {
            type = types.path;
            default = "/var/lib/syncthing";
            description = "Syncthing state directory (keys, indexes, database).";
        };

        user = mkOption {
            type = types.str;
            default = config.metadata.user;
            description = "User for the Syncthing systemd service.";
        };

        group = mkOption {
            type = types.str;
            default = "users";
            description = "Group for the Syncthing systemd service.";
        };

        overrideDevices = mkOption {
            type = types.bool;
            default = false;
            description = ''
              When true, devices not listed under `settings.devices` are removed on each
              `syncthing-init` run. The REST API includes this host's own device ID, so leaving
              `settings.devices` empty with `true` would delete the local device and break Syncthing.
              Keep `false` unless you fully declare every peer (and understand Syncthing/NixOS behavior).
            '';
        };

        overrideFolders = mkOption {
            type = types.bool;
            default = true;
            description = ''
              When true, folders added only in the GUI are removed on restart.
              Set false to manage some folders only in the GUI (not recommended together with autoAcceptFolders).
            '';
        };

        folders = mkOption {
            type = types.attrsOf folderModule;
            default = { };
            description = ''
              Syncthing folders to declare on this host (merged into `services.syncthing.settings.folders`).
              Use one attribute per folder; the name is the default folder ID (override with `id`).

              Pair peers via `settings.devices` and each folder's `devices` list (device name keys).
            '';
        };

        settings = mkOption {
            type = settingsFormat.type;
            default = { };
            description = ''
              Extra `services.syncthing.settings` (devices, folders, options, gui, …).
              Merged with `folders`; explicit `settings.folders` entries merge with the same keys.
            '';
        };
    };

    config = mkIf cfg.enable {
        systemd.tmpfiles.rules = [
            "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
        ];

        services.syncthing = {
            enable = true;
            user = cfg.user;
            group = cfg.group;
            dataDir = cfg.dataDir;
            openDefaultPorts = cfg.openDefaultPorts;
            guiAddress = "127.0.0.1:${toString cfg.guiPort}";
            overrideDevices = cfg.overrideDevices;
            overrideFolders = cfg.overrideFolders;
            settings = mergedSettings;
        };

        # RequiresMountsFor belongs in [Unit], not [Service] (systemd ignores it there).
        systemd.services.syncthing = mkIf (folderMountPaths != [ ]) {
            unitConfig.RequiresMountsFor = folderMountPaths;
        };

        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "syncthing";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:${toString cfg.guiPort}";
            }
        ];

        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "Syncthing";
                subdomain = cfg.subdomain;
                icon = "mdi:sync";
                group = "Other";
            }
        ];
    };
}
