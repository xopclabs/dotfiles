{ config, pkgs, lib, ... }:

{
    # DigitalOcean serves the public IP over DHCP. Using DHCP keeps networking
    # independent of sops decryption so a secrets issue can't lock us out.
    networking = {
        useDHCP = true;
        nameservers = [ "9.9.9.9" "1.1.1.1" ];
    };

    # Don't block boot waiting for a specific interface to come online
    systemd.network.wait-online.enable = false;
}
