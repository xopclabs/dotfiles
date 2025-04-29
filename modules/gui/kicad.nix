{ pkgs, lib, config, inputs, ... }:

with lib;
let
    cfg = config.modules.gui.kicad;
    kicadColorSchemes = pkgs.fetchFromGitHub {
        owner = "pointhi";
        repo = "kicad-color-schemes";
        rev = "68ea0402f334bdbae175f6ca924743640c07183d";
        sha256 = "sha256-PYgFOyK5MyDE1vTkz5jGnPWAz0pwo6Khu91ANgJ2OO4=";
    };
    kicadTheme = "nord";
in {
    options.modules.gui.kicad = { enable = mkEnableOption "kicad"; };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            kicad-small
        ];
        home.file.".config/kicad/8.0/colors" = {
            source = "${kicadColorSchemes}/${kicadTheme}";
            recursive = true;
        };
    };
}
