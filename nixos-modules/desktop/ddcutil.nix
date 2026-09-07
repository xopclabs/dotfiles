{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.ddcutil;
    chmod = "${pkgs.coreutils}/bin/chmod";
    chgrp = "${pkgs.coreutils}/bin/chgrp";
    applyPerms = pkgs.writeShellScript "ddcutil-i2c-permissions" ''
        set -eu
        ${pkgs.systemd}/bin/udevadm trigger -s i2c-dev --action=change || true
        for d in /dev/i2c-*; do
            [ -e "$d" ] || continue
            ${chgrp} i2c "$d" || true
            ${chmod} 0660 "$d" || true
        done
    '';
in {
    options.desktop.ddcutil = {
        enable = mkEnableOption "DDC/CI brightness for external monitors (ddcutil)";
    };

    config = mkIf cfg.enable {
        hardware.i2c.enable = true;
        boot.kernelModules = [ "i2c-dev" ];
        environment.systemPackages = [ pkgs.ddcutil ];
        users.users.${config.metadata.user}.extraGroups = [ "i2c" ];

        # hardware.i2c MODE/GROUP is not applied to already-present nodes after
        # a switch, and uaccess ACLs do not stick on this kernel. Force them.
        services.udev.extraRules = ''
            ACTION=="add|change", SUBSYSTEM=="i2c-dev", KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660", RUN+="${chgrp} i2c /dev/%k", RUN+="${chmod} 0660 /dev/%k"
        '';

        systemd.services.ddcutil-i2c-permissions = {
            description = "Grant i2c group access to DDC buses";
            wantedBy = [ "multi-user.target" ];
            after = [ "systemd-udevd.service" ];
            serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = applyPerms;
            };
        };
    };
}
