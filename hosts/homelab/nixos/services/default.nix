{ config, pkgs, inputs, ... }:

{
    imports = [
        ./wireguard/wireguard.nix
        ./ddns.nix
    ];
}
