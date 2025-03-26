{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.yazi;

in {
    options.modules.yazi = { enable = mkEnableOption "yazi"; };
    config = mkIf cfg.enable {
        programs.yazi = {
            enable = true;
            enableZshIntegration = true;

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
                        { name = "py"; text = ""; fg = "red"; }
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

        programs.zsh.shellAliases = {
            y = "yazi";
        };

        # Install optional dependencies
        home.packages = with pkgs; [
            poppler
            jq
            fd
            ripgrep
            imagemagick
        ];
    };
} 
