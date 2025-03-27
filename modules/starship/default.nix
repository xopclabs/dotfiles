{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.starship;
    # Semantically named color variables
    colors = with config.colorScheme.palette; {
        bg_primary = base0B;
        bg_secondary = base0D;
        bg_tertiary = base0A;
        bg_default = base00;
        
        fg_primary = base00;
        fg_secondary = base05;
        fg_tertiary = base01;
        
        accent_success = base0B;
        accent_error = base08;
        accent_warning = base09;
        accent_info = base0C;
        accent_purple = base0E;
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
            settings = with colors; {
                format = concatStrings [
                    "$os"
                    "$username"
                    (optionalString cfg.aws.enable "$aws")
                    "$directory"
                    "$git_branch"
                    "$git_status"
                    "$git_metrics"
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
                    style = "bg:#${bg_primary} fg:#${fg_primary}";
                    symbols = {
                        Windows = "󰍲";
                        Ubuntu = "󰕈";
                        Macos = "󰀵";
                        Amazon = "";
                        Arch = "󰣇";
                        Debian = "󰣚";
                        NixOS = "";
                    };
                };

                username = {
                    show_always = true;
                    style_user = "bg:#${bg_primary} fg:#${fg_primary}";
                    style_root = "bg:#${bg_primary} fg:#${accent_error}";
                    format = "[ $user ]($style)";
                };

                hostname = {
                    ssh_only = true;
                    ssh_symbol = " ";
                    format = "[@ $hostname ]($style)";
                    style = "fg:#${fg_primary} bg:#${bg_primary}";
                    disabled = false;
                };

                aws = mkIf cfg.aws.enable {
                    format = "[ $symbol $region ]($style)";
                    style = "fg:#${fg_primary} bg:#${accent_warning}";
                    symbol = " ";
                };

                directory = {
                    format = "[ 󰉋  $path ]($style)";
                    style = "fg:#${fg_secondary} bg:#${bg_secondary}";
                };

                git_branch = {
                    format = "[](fg:#${bg_default} bg:#${bg_tertiary})[ $symbol $branch(:$remote_branch) ]($style)[](fg:#${bg_tertiary} bg:#${bg_default})";
                    symbol = "";
                    style = "fg:#${fg_tertiary} bg:#${bg_tertiary}";
                    disabled = false;
                };

                git_status = {
                    format = "[$all_status]($style)";
                    style = "fg:#${fg_tertiary} bg:#${bg_tertiary}";
                    disabled = false;
                };

                git_metrics = {
                    format = "([+$added]($added_style))[ ]($added_style)";
                    added_style = "fg:#${fg_tertiary} bg:#${bg_tertiary}";
                    deleted_style = "fg:#${accent_error} bg:#${bg_tertiary}";
                    disabled = false;
                    only_nonzero_diffs = true;
                };

                character = {
                    success_symbol = "[ ➜](bold #${accent_success}) ";
                    error_symbol = "[ ](bold #${accent_error}) ";
                };

                conda = {
                    format = "[ $symbol$environment ]($style)";
                    symbol = " ";
                    style = "fg:#${fg_primary} bg:#${accent_info}";
                    ignore_base = false;
                };

                direnv = {
                    format = "[ $symbol$loaded ]($style)";
                    symbol = " ";
                    style = "fg:#${fg_primary} bg:#${accent_info}";
                };

                nix_shell = {
                    format = "[ $symbol $state ]($style)";
                    symbol = " ";
                    style = "fg:#${fg_primary} bg:#${accent_info}";
                };

                cmd_duration = {
                    min_time = 1000;
                    format = "[ 󱑎 $duration ]($style)";
                    style = "fg:#${fg_primary} bg:#${accent_purple}";
                };
            };
        };
    };
}
