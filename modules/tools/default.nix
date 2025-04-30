{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.tools;
in {
    imports = [
        ./awscli.nix
        ./btop.nix
        ./git.nix
        ./gpg.nix
        ./nh.nix
        ./ssh.nix
        ./tldr.nix
        ./udiskie.nix
        ./scripts/scripts.nix
    ];
}
