{ inputs, pkgs, config, lib, utils, ... }:

with lib;
let
    cfg = config.modules.other;
in {
    imports = [
        ./kicad.nix
        ./plover.nix
        ./minecraft.nix
        ./mangohud.nix
        ./androidcam.nix
        ./phone-control.nix
        ./autofirma.nix
        ./sops-age-key.nix
    ];
}
