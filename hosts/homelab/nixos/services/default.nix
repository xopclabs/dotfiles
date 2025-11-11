{ config, pkgs, inputs, ... }:

{
    imports = [
        ./wireguard/wireguard.nix
        ./ddns.nix
        ./pihole_unbound.nix
        ./minecraft.nix
    ];
}
