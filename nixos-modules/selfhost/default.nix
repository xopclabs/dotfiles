{ config, lib, pkgs, inputs, ... }:

with lib;
{
    imports = [
        ./traefik.nix
        ./pihole-unbound/pihole-unbound.nix
        ./postgres.nix
        ./traccar.nix
        ./nextcloud.nix
        ./minecraft.nix
        ./ddns.nix
        ./transmission.nix
        ./arr-stack/arr-stack.nix
        ./wireguard/wireguard.nix
        ./glance.nix
        ./scrutiny.nix
        ./borgbackup.nix
        ./keepalived.nix
        ./wallos.nix
    ];
}

