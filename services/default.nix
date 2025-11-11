{ config, lib, pkgs, inputs, ... }:

with lib;
{
    imports = [
        ./pihole_unbound.nix
        ./minecraft.nix
        ./ddns.nix
        ./wireguard/wireguard.nix
    ];
}

