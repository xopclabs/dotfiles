{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.starship;
    # Nord theme colors
    colors = with config.colorScheme.palette; {

        gray_darkest = base00;
        gray_darker = base01;
        gray_lighter = base02;
        gray_lightest = base03;
        
        white_darkest = base04;
        white_darker = base05;
        white_lightest = base06;
        
        teal = base07;
        red = base08;
        orange = base09;
        yellow = base0A;
        green = base0B;
        cyan = base0C;
        blue = base0D;
        purple = base0E;
        blue_dark = base0F;
    };
in {
    options.modules.starship = {
        enable = mkEnableOption "starship";
        aws = {
            enable = mkEnableOption "aws module";
        };
    };
    config = mkIf cfg.enable {
        programs.starship = {
            enable = true;
            enableZshIntegration = true;
            settings = with colors; let
                fg = gray_darkest;
                git_bg = gray_darker;
                git_fg = white_darkest;
            in {
                format = concatStrings [
                    "$os"
                    "$username"
                    (optionalString cfg.aws.enable "$aws")
                    "$directory"
                    "$git_branch"
                    "$git_commit"
                    "$git_metrics"
                    "$git_status"
                    "$character"
                ];
                
                right_format = concatStrings [
                    "$direnv"
                    "$nix_shell"
                    "$conda"
                    "$cmd_duration"
                ];
                
                add_newline = false;

                line_break = {
                    disabled = true;
                };

                os = {
                    disabled = false;
                    format = "[ $symbol ]($style)";
                    style = "bg:#${green} fg:#${fg}";
                    symbols = {
                        Windows = "󰍲";
                        Ubuntu = "󰕈";
                        Macos = "󰀵";
                        Amazon = "";
                        Arch = "󰣇";
                        Debian = "󰣚";
                        NixOS = "󱄅";
                    };
                };
                username = {
                    show_always = true;
                    style_user = "bg:#${green} fg:#${fg}";
                    style_root = "bg:#${red} fg:#${fg}";
                    format = "[$user ]($style)";
                };
                hostname = {
                    ssh_only = true;
                    ssh_symbol = "";
                    format = "[@$hostname]($style)";
                    style = "bg:#${green} fg:#${fg} ";
                    disabled = false;
                };

                aws = mkIf cfg.aws.enable {
                    format = "[ $symbol $region ]($style)";
                    style = "bg:#${orange} fg:#${fg} ";
                    symbol = "";
                    force_display = true;
                };

                directory = {
                    format = "[ 󰉋 $path ]($style)";
                    style = "bg:#${blue} fg:#${fg} ";
                };

                git_branch = {
                    format = concatStrings [
                        "[ $symbol $branch(:$remote_branch) ]($style)"
                    ];
                    symbol = "";
                    style = "bg:#${git_bg} fg:#${git_fg}";
                    only_attached = true;
                    disabled = false;
                };

                git_commit = {
                    format = concatStrings [
                        "([$hash$tag ]($style))"
                    ];
                    style = "bg:#${git_bg} fg:#${git_fg}";
                    tag_symbol = "";
                    tag_disabled = false;
                    disabled = false;
                };

                git_metrics = {
                    format = "(([+$added]($added_style))([-$deleted]($deleted_style))[ ](bg:#${git_bg}))";
                    added_style = "bg:#${git_bg} fg:#${green}";
                    deleted_style = "bg:#${git_bg} fg:#${red}";
                    disabled = false;
                    only_nonzero_diffs = true;
                };

                git_status = {
                    format = "([$ahead_behind$untracked$modified$deleted$renamed$staged$conflicted ]($style))";
                    ahead = "⇡\${count}";
                    diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
                    behind = "⇣\${count}";
                    untracked = "?\${count}";
                    modified = "!\${count}";
                    staged = "+\${count}";
                    deleted = "\${count}";
                    conflicted = "\${count}";
                    style = "bg:#${git_bg} fg:#${git_fg} ";
                    disabled = false;
                };

                character = {
                    success_symbol = "[ ➜](bold #${green}) ";
                    error_symbol = "[ ](bold #${red}) ";
                };

                conda = {
                    format = "[ $symbol$environment ]($style)";
                    symbol = " ";
                    style = "bg:#${cyan} fg:#${fg}";
                    ignore_base = false;
                };

                direnv = {
                    format = "[ $symbol$loaded ]($style)";
                    symbol = " ";
                    style = "bg:#${cyan} fg:#${fg}";
                };

                nix_shell = {
                    format = "[ $symbol$state ]($style)";
                    symbol = " ";
                    style = "bg:#${cyan} fg:#${fg}";
                };

                cmd_duration = {
                    min_time = 1000;
                    format = "[ 󱑎 $duration ]($style)";
                    style = "bg:#${purple} fg:#${fg}";
                };
            };
        };
    };
}
