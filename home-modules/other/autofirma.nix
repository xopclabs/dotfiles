{ pkgs, lib, config, inputs, ... }:

with lib;
let
    cfg = config.modules.other.autofirma;
in {
    options.modules.other.autofirma = { enable = mkEnableOption "autofirma"; };
    config = mkIf cfg.enable {
        programs.autofirma = {
            enable = true;
            firefoxIntegration.profiles.${config.home.username} = {
                enable = true;
            };
        };

        programs.configuradorfnmt = {
            enable = true;
            firefoxIntegration.profiles.${config.home.username} = {
                enable = true;
            };
        };

        programs.dnieremote = {
            enable = true;
        };

        programs.firefox = {
            enable = true;
            policies = {
                SecurityDevices = {
                    "OpenSC PKCS11" = "${pkgs.opensc}/lib/opensc-pkcs11.so";
                    "DNIeRemote" = "${config.programs.dnieremote.finalPackage}/lib/libdnieremotepkcs11.so";
                };
            };
            profiles.${config.home.username} = {
                id = 0;
            };
        };
    };
}