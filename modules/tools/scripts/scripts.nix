{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.tools.scripts;
    tm = pkgs.writeShellScriptBin "tm" ''${builtins.readFile ./tm.sh}'';
    freshman_start = pkgs.writeShellScriptBin "freshman_start" ''${builtins.readFile ./freshman_start.sh}'';
    see = pkgs.writeShellScriptBin "see" ''${builtins.readFile ./see.sh}'';
    ssh-tmux = pkgs.writeShellScriptBin "ssh-tmux" ''${builtins.readFile ./ssh-tmux.sh}'';
    run-training = pkgs.writeShellScriptBin "run-training" ''${builtins.readFile ./run-training.sh}'';
in {
    options.modules.tools.scripts = { enable = mkEnableOption "scripts"; };
    config = mkIf cfg.enable {
        home.packages = [
            tm
            see
            ssh-tmux
            run-training
        ];
    };
}
