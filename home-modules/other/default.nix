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
        ./phone-control/phone-control.nix
        ./phone-control/relay.nix
        ./phone-control/webcam.nix
        ./autofirma.nix
        ./sops-age-key.nix
    ];
}
