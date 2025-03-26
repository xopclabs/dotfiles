{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.scripts;
    maintenance = pkgs.writeShellScriptBin "maintenance" ''${builtins.readFile ../scripts/maintenance}'';
    sftpmpv = pkgs.writeShellScriptBin "sftpmpv" ''${builtins.readFile ../scripts/sftpmpv}'';
    tm = pkgs.writeShellScriptBin "tm" ''${builtins.readFile ../scripts/tm}'';
    freshman_start = pkgs.writeShellScriptBin "freshman_start" ''${builtins.readFile ../scripts/freshman_start}'';
    see = pkgs.writeShellScriptBin "see" ''${builtins.readFile ../scripts/see}'';
in {
    options.modules.scripts = { enable = mkEnableOption "scripts"; };
    config = mkIf cfg.enable {
        home.packages = [
            # scripts
            maintenance
            sftpmpv
            tm
            freshman_start
            see
        ];
    };
}
