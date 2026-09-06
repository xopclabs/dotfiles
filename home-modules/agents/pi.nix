{ pkgs, lib, config, ... }:

with lib;
let
    cfg = config.modules.agents.pi;
    json = pkgs.formats.json { };
    configDir = config.programs.pi-coding-agent.configDir;
    settingsFile = json.generate "pi-settings.json" {
        theme = "dark";
        defaultProvider = "openai-codex";
        enableInstallTelemetry = false;
        tuiMode = "regular";
        packages = [ "npm:pi-web-access@0.28.0" ];
    };
in {
    options.modules.agents.pi = { enable = mkEnableOption "pi"; };
    config = mkIf cfg.enable {
        programs.pi-coding-agent = {
            enable = true;
            extraPackages = with pkgs; [
                nodejs bun git jq fd ripgrep
                ffmpeg yt-dlp xdg-utils
            ];
        };

        # Copy, do not symlink: /settings and `pi install` can write, then the next rebuild resets to this baseline.
        home.activation.piSettingsBaseline = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            mkdir -p "${configDir}"
            $DRY_RUN_CMD cp -f ${settingsFile} "${configDir}/settings.json"
            $DRY_RUN_CMD chmod u+w "${configDir}/settings.json"
            $DRY_RUN_CMD rm -rf "${configDir}/npm" "${configDir}/git"
        '';
    };
}
