{ config, pkgs, inputs, ... }:

{
    networking = {
        useDHCP = true;
            interfaces.ens3 = {
                useDHCP = true;
        };
        nameservers = [ "9.9.9.9" ];
        
        networkmanager = {
            enable = true;
            dns = "default";
        };
    };
}
