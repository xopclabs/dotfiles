{ pkgs, lib, config, ... }:

with lib;
let
    cfg = config.modules.cli.nh;
    nhWithSudo = pkgs.writeShellScriptBin "nh" ''
        sudo -v || exit "$?"

        # Refresh only an existing credential; never prompt in the background.
        (
            while ${pkgs.coreutils}/bin/sleep 30; do
                sudo -n -v || exit
            done
        ) &
        keepalive=$!
        cleanup() {
            kill "$keepalive" 2>/dev/null || true
            wait "$keepalive" 2>/dev/null || true
        }
        trap cleanup EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM

        ${pkgs.nh}/bin/nh "$@"
    '';
    wrappedNh = pkgs.symlinkJoin {
        name = "nh-with-sudo-keepalive";
        paths = [ pkgs.nh ];
        postBuild = ''
            rm "$out/bin/nh"
            ln -s ${nhWithSudo}/bin/nh "$out/bin/nh"
        '';
    };

in {
    options.modules.cli.nh = { 
        enable = mkEnableOption "nh"; 
    };
    config = mkIf cfg.enable {
        programs.nh = {
            enable = true;
            package = wrappedNh;
        };
    };
}
