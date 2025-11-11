{ config, lib, pkgs, inputs, ... }:

with lib;
{
    imports = [
        ./traefik.nix
        ./pihole_unbound.nix
        ./minecraft.nix
        ./ddns.nix
        ./wireguard/wireguard.nix
    ];
}

