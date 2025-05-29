{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.players.video.mpv;
    remotempv = pkgs.writeShellScriptBin "remotempv" ''${builtins.readFile ./remotempv.sh}'';
    sftpmpv = pkgs.writeShellScriptBin "sftpmpv" ''${builtins.readFile ./sftpmpv.sh}'';
in {
    options.modules.players.video.mpv = { enable = mkEnableOption "mpv"; };
    config = mkIf cfg.enable {
        programs.mpv = {
            enable = true;
            bindings = {
                "Shift+Left"  = "playlist-prev";
                "Shift+Right"  = "playlist-next";
            };
            config = {
                loop-file = "inf";
                cache = "yes";
                cache-secs = 300;
                cache-on-disk = "yes";
                demuxer-cache-dir = "${config.xdg.configHome}/.cache/mpv";

                osd-font-size = 8; 
                osd-outline-size = 1;
            };
        };
        home.packages = [
            remotempv pkgs.rsync pkgs.sshfs
        ];
        programs.zsh.initContent = lib.mkOrder 1000 ''
            source ${./remotempv.completion.sh}
        '';
    };
}
