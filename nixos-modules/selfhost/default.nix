{ config, lib, pkgs, inputs, ... }:

with lib;
{
    imports = [
        ./traefik.nix
        ./pihole-unbound.nix
        ./postgres.nix
        ./traccar.nix
        ./minecraft.nix
        ./ddns.nix
        ./transmission.nix
        ./arr-stack/arr-stack.nix
        ./wireguard/wireguard.nix
        ./glance.nix
    ];
}

