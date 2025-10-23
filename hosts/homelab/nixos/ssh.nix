{ config, pkgs, inputs, ... }:

{
    services.openssh = {
        enable = true;
        settings = {
            PermitRootLogin = "no";
            PasswordAuthentication = false;
        };
        authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAFmiLCnm7UOpY9Ak+gxJcsHXBZOfyWiFtl35c49CjjE"
        ];
    };
}