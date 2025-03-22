{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.starship;

in {
    options.modules.starship = { 
        enable = mkEnableOption "starship"; 
        icon = mkOption {
            type = types.str;
            default = "󱄅";
            description = "The icon to use for the starship prompt";
        };
    };
    config = mkIf cfg.enable {
        programs.starship = {
            enable = true;
            enableZshIntegration = true;
        };
        home.file."${config.xdg.configHome}/starship.toml".text = with config.colorScheme.palette; ''
            format = """\
            [ ](bg:#${base00} fg:#${base0B})\
            [ ${cfg.icon} ](bg:#${base0B} fg:#${base00})\
            [ ](fg:#${base0B} bg:#${base02})\
            $time\
            [](fg:#${base02} bg:#${base0D})\
            $directory\
            [](fg:#${base0D} bg:#${base0A})\
            $git_branch\
            $git_status\
            $git_metrics\
            [](fg:#${base0A} bg:#${base00})\
            $character\
            """
            add_newline = false

            [line_break]
            disabled = true

            [directory]
            format = "[ 󰉋 $path ]($style)"
            style = "fg:#${base05} bg:#${base0D}"

            [git_branch]
            format = '[ $symbol$branch(:$remote_branch) ]($style)'
            symbol = " "
            style = "fg:#${base01} bg:#${base0A}"

            [git_status]
            format = '[$all_status]($style)'
            style = "fg:#${base01} bg:#${base0A}"

            [git_metrics]
            format = "([+$added]($added_style))[]($added_style)"
            added_style = "fg:#${base01} bg:#${base0A}"
            deleted_style = "fg:#${base08} bg:#${base01}"
            disabled = false

            [hg_branch]
            format = "[ $symbol$branch ]($style)"
            symbol = " "

            [cmd_duration]
            format = "[  $duration ]($style)"
            style = "fg:#${base06} bg:#${base01}"

            [character]
            success_symbol = '[ ➜](bold #${base0B}) '
            error_symbol = '[ ✗](#${base08}) '

            [time]
            disabled = false
            time_format = "%R" # Hour:Minute Format
            style = "bg:#${base01}"
            format = '[[󱑍 $time ](bg:#${base02} fg:#${base0C})]($style)'
        '';
    };
}
