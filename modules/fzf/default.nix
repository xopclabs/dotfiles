{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.fzf;

in {
    options.modules.fzf = { enable = mkEnableOption "fzf"; };

    config = mkIf cfg.enable {

        home.packages = with pkgs; [
            fd
            bat
            eza
        ];

        programs.fzf = {
            enable = true;
            enableZshIntegration = true;
            defaultCommand = "fd --type f --hidden --exclude .git";
            fileWidgetCommand = "fd --type f --hidden --exclude .git";
            changeDirWidgetCommand = "fd --type d --hidden --exclude .git";
            colors = with config.colorScheme.palette; {
                fg = "#${base05}";
                "fg+" = "#${base06}";
                bg = "#${base00}";
                "bg+" = "#${base01}";
                hl = "#${base0D}";
                "hl+" = "#${base0D}";
                info = "#${base0A}";
                prompt = "#${base0E}";
                pointer = "#${base0C}";
                marker = "#${base0B}";
                spinner = "#${base0E}";
                header = "#${base05}";
            };
            fileWidgetOptions = [
                "--preview 'bat --color=always --style=numbers --line-range=:500 {}'"
            ];
            changeDirWidgetOptions = [
                "--preview 'eza -1 --color=always --icons=always {}'"
            ];
            historyWidgetOptions = [
                "--sort"
            ];
        };
    };
}
