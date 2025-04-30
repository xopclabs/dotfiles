{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.tools.scripts;
    maintenance = pkgs.writeShellScriptBin "maintenance" ''${builtins.readFile ./maintenance}'';
    sftpmpv = pkgs.writeShellScriptBin "sftpmpv" ''${builtins.readFile ./sftpmpv}'';
    tm = pkgs.writeShellScriptBin "tm" ''${builtins.readFile ./tm}'';
    freshman_start = pkgs.writeShellScriptBin "freshman_start" ''${builtins.readFile ./freshman_start}'';
    see = pkgs.writeShellScriptBin "see" ''${builtins.readFile ./see}'';
    ssh-tmux = pkgs.writeShellScriptBin "ssh-tmux" ''${builtins.readFile ./ssh-tmux}'';
    run-training = pkgs.writeShellScriptBin "run-training" ''${builtins.readFile ./run-training}'';
in {
    options.modules.tools.scripts = { enable = mkEnableOption "scripts"; };
    config = mkIf cfg.enable {
        home.packages = [
            maintenance
            sftpmpv
            tm
            freshman_start
            see
            ssh-tmux
            run-training
        ];
    };
}
