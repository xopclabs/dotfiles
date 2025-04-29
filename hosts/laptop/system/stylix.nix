{ config, pkgs, ... }:

{
    stylix = {
        enable = true;
        autoEnable = false;
        base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";
        targets.console.enable = true;
        targets.grub.enable = true;
    };
}
