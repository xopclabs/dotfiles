{ config, pkgs, inputs, ... }:

{
    imports = [
        ./wireguard/wireguard.nix
    ];
}
