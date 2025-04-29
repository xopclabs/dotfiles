{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.fileManagers.yazi;

in {
    options.modules.fileManagers.yazi = { enable = mkEnableOption "yazi"; };
    config = mkIf cfg.enable {
        programs.yazi = {
            enable = true;
            enableZshIntegration = config.modules.cli.zsh.enable;
            shellWrapperName = "y";

            settings = {
                manager = {
                    ratio = [ 2 6 7 ];
                    sort_by = "mtime";
                    sort_reverse = true;
                    linemode = "size";
                };
                preview = {
                    tab_size = 4;
                };
                opener.play = [
                    { run = "vlc \"$@\""; orphan = true; for = "unix"; }
                ];
            };

            theme = {
                manager = {
                    border_symbol = " ";
                };
                status = {
                    sep_left = { open = ""; close = ""; };
                    sep_right = { open = ""; close = ""; };
                };
                icon = {
                    exts = [
                        { name = "py"; text = ""; fg = "blue"; }
                    ]; 
                };
            };

            initLua = ''
                -- Show symlink path
                Status:children_add(function(self)
                    local h = self._current.hovered
                    if h and h.link_to then
                        return " -> " .. tostring(h.link_to)
                    else
                        return ""
                    end
                end, 3300, Status.LEFT)
            '';
        };

        # Install optional dependencies
        home.packages = with pkgs; [
            mktemp
            poppler
            jq
            fd
            ripgrep
            imagemagick
        ];
    };
} 
