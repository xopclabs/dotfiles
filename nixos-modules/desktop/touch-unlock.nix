{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.desktop.touchUnlock;
    udevUnits = [
        "systemd-udevd.service"
        "systemd-udev-trigger.service"
    ];

    themedBuffybox = pkgs.buffybox.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ../../patches/buffybox/xopc-unl0kr-theme.patch ];
    });

    knownInputRules = ''
        # Built-in QDtech MPI7003 touchscreen used by pc.
        ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{id/vendor}=="0484", ATTRS{id/product}=="5750", ENV{ID_INPUT}="1", ENV{ID_INPUT_TOUCHSCREEN}="1"

        # 2.4G USB receiver used as an emergency pointer/keyboard fallback on pc.
        ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ATTRS{id/vendor}=="25a7", ATTRS{id/product}=="fa11", ENV{ID_INPUT}="1", ENV{ID_INPUT_MOUSE}="1"
    '';
in
{
    options.desktop.touchUnlock = {
        enable = mkEnableOption "touchscreen initrd unlock UI";

        package = mkOption {
            type = types.package;
            default = themedBuffybox;
            description = "Buffybox/unl0kr package to use.";
        };

        allowVendorDrivers = mkOption {
            type = types.bool;
            default = false;
            description = "Load optional unl0kr vendor touchscreen drivers.";
        };

        terminalKeyboardFallback = mkOption {
            type = types.bool;
            default = true;
            description = "Keep terminal keyboard input enabled as a fallback while unl0kr is running.";
        };

        extraKernelModules = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Extra kernel modules to include in initrd for touch/pointer devices.";
        };

        includeKnownInputRules = mkOption {
            type = types.bool;
            default = true;
            description = "Include known harmless initrd udev classifications for touchscreen unlock devices used by these hosts.";
        };

        extraUdevRules = mkOption {
            type = types.lines;
            default = "";
            description = "Extra initrd udev rules for devices unl0kr/libinput does not classify correctly.";
        };

        inputSettleTimeoutSec = mkOption {
            type = types.ints.unsigned;
            default = 1;
            description = "Seconds to wait for initrd udev input devices before starting unl0kr.";
        };
    };

    config = mkIf cfg.enable {
        # unl0kr is a systemd password agent with an on-screen keyboard, so it
        # can answer the systemd-cryptsetup TPM PIN / passphrase prompt in initrd.
        boot.initrd = {
            availableKernelModules = [
                "mousedev"
                "uhid"
            ] ++ cfg.extraKernelModules;
            services.udev.rules = optionalString cfg.includeKnownInputRules knownInputRules + cfg.extraUdevRules;
            systemd = {
                enable = true;
                extraBin.udevadm = "${config.boot.initrd.systemd.package}/bin/udevadm";
                paths.unl0kr-agent = {
                    wants = udevUnits ++ [ "unl0kr-input-ready.service" ];
                    after = udevUnits ++ [ "unl0kr-input-ready.service" ];
                };
                services = {
                    unl0kr-input-ready = {
                        before = [ "unl0kr-agent.service" ];
                        after = udevUnits;
                        wants = udevUnits;
                        unitConfig.DefaultDependencies = "no";
                        serviceConfig.Type = "oneshot";
                        script = ''
                            udevadm settle --timeout=${toString cfg.inputSettleTimeoutSec} || true
                        '';
                    };
                    unl0kr-agent = {
                        wants = [ "unl0kr-input-ready.service" ];
                        after = [ "unl0kr-input-ready.service" ];
                        # NixOS' unl0kr module imports upstream units from pkgs.buffybox
                        # even when boot.initrd.unl0kr.package is overridden. Keep the
                        # unit, but point it at our patched package that is actually in
                        # the initrd store closure.
                        serviceConfig.ExecStart = mkForce [
                            ""
                            "${cfg.package}/libexec/unl0kr-agent"
                        ];
                    };
                };
            };
            unl0kr = {
                enable = true;
                package = cfg.package;
                allowVendorDrivers = cfg.allowVendorDrivers;
                settings = {
                    general = {
                        animations = true;
                        backend = "drm";
                    };
                    keyboard = {
                        autohide = false;
                        layout = "us";
                        popovers = true;
                    };
                    input = {
                        keyboard = true;
                        pointer = true;
                        touchscreen = true;
                    };
                    quirks.terminal_allow_keyboard_input = cfg.terminalKeyboardFallback;
                    textarea.obscured = true;
                    theme = {
                        default = "nord-dark";
                        alternate = "nord-dark";
                    };
                };
            };
        };
    };
}
