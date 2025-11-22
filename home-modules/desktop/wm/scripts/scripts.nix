{ config, pkgs, lib, ... }:

with lib;
let 
    cfg = config.modules.desktop.wm.scripts;
    screenshot = pkgs.writeShellScriptBin "screenshot" ''
    	grim -g "$(slurp -d)" - | wl-copy
    '';
    annotate = pkgs.writeShellScriptBin "annotate" ''
        wl-paste | swappy -f - -o - | wl-copy
    '';
    screenrecord = pkgs.writeShellScriptBin "screenrecord" ''
        # Check if wf-recorder is currently running
        if pgrep -x wf-recorder > /dev/null; then
            echo "Stopping wf-recorder..."
            pkill -SIGINT wf-recorder
        else
            echo "Starting wf-recorder..."
            wf-recorder -g "$(slurp)" -f ~/screenshots/$(date +'%Y-%m-%d_%H-%M-%S').mkv &
        fi
    '';
in {
    options.modules.desktop.wm.scripts = { 
        enable = mkEnableOption "scripts";
    };

    config = mkIf cfg.enable {
        home.packages = [
            screenshot pkgs.grim pkgs.slurp
            annotate pkgs.swappy
            screenrecord pkgs.wf-recorder
            pkgs.wl-clipboard
        ];
    };
}
