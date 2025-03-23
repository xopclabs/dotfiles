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
    options.modules.starship = { enable = mkEnableOption "starship"; };
    config = mkIf cfg.enable {
        programs.starship = {
            enable = true;
            enableZshIntegration = true;
        };
        home.file."${config.xdg.configHome}/starship.toml".text = with colors; ''
            # Main prompt format (left side)
            format = """\
            [](fg:#${bg_default} bg:#${bg_default})\
            $os\
            $username\
            [ ](fg:#${bg_primary} bg:#${bg_secondary})\
            $directory\
            $git_branch\
            $git_status\
            $git_metrics\
            $character\
            """
            
            # Right side prompt format
            right_format = """\
            $direnv\
            $nix_shell\
            $conda\
            $cmd_duration\
            """
            
            add_newline = false

            [line_break]
            disabled = true

            [os]
            disabled = false
            format = "[ $symbol ]($style)"
            style = "bg:#${bg_primary} fg:#${fg_primary}"

            [os.symbols]
            Windows = "󰍲"
            Ubuntu = "󰕈"
            SUSE = ""
            Raspbian = "󰐿"
            Mint = "󰣭"
            Macos = "󰀵"
            Manjaro = ""
            Linux = "󰌽"
            Gentoo = "󰣨"
            Fedora = "󰣛"
            Alpine = ""
            Amazon = ""
            Android = ""
            Arch = "󰣇"
            Artix = "󰣇"
            EndeavourOS = ""
            CentOS = ""
            Debian = "󰣚"
            Redhat = "󱄛"
            RedHatEnterprise = "󱄛"
            Pop = ""
            NixOS = ""

            [username]
            show_always = true
            style_user = "bg:#${bg_primary} fg:#${fg_primary}"
            style_root = "bg:#${bg_primary} fg:#${accent_error}"
            format = '[ $user ]($style)'            

            [directory]
            format = "[ 󰉋 $path ]($style)"
            style = "fg:#${fg_secondary} bg:#${bg_secondary}"

            [git_branch]
            format = '[](fg:#${bg_default} bg:#${bg_tertiary})[ $symbol$branch(:$remote_branch) ]($style)[](fg:#${bg_tertiary} bg:#${bg_default})'
            symbol = " "
            style = "fg:#${fg_tertiary} bg:#${bg_tertiary}"
            disabled = false

            [git_status]
            format = '[$all_status]($style)'
            style = "fg:#${fg_tertiary} bg:#${bg_tertiary}"
            disabled = false

            [git_metrics]
            format = "([+$added]($added_style))[ ]($added_style)"
            added_style = "fg:#${fg_tertiary} bg:#${bg_tertiary}"
            deleted_style = "fg:#${accent_error} bg:#${bg_tertiary}"
            disabled = false
            only_nonzero_diffs = true

            [character]
            success_symbol = '[ ➜](bold #${accent_success}) '
            error_symbol = '[ ✗](#${accent_error}) '

            # Conda environment - only shown when active
            [conda]
            format = '[ $symbol$environment ]($style)'
            symbol = " "
            style = "fg:#${fg_primary} bg:#${accent_info}"
            ignore_base = false

            [direnv]
            format = '[ $symbol$loaded ]($style)'
            symbol = " "
            style = "fg:#${fg_primary} bg:#${accent_info}"

            [nix_shell]
            format = '[ $symbol $state ]($style)'
            symbol = " "
            style = "fg:#${fg_primary} bg:#${accent_info}"

            # Command duration - only shown when a command takes longer than min_time
            [cmd_duration]
            min_time = 1000
            format = '[ 󱑎 $duration ]($style)'
            style = "fg:#${fg_primary} bg:#${accent_purple}"
        '';
    };
}
