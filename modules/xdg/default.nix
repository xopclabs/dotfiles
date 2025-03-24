{ inputs, pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.xdg;
in {
    options.modules.xdg = { 
        enable = mkEnableOption "xdg"; 
        browser = mkOption {
            type = types.str;
            default = "firefox.desktop";
        };
        file-manager = mkOption {
            type = types.str;
            default = "nautilus.desktop";
        };
        image-viewer = mkOption {
            type = types.str;
            default = "loupe.desktop";
        };
        video-player = mkOption {
            type = types.str;
            default = "vlc.desktop";
        };
    };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            nautilus
            loupe
        ];
        xdg.userDirs = {
            enable = true;
            documents = "$HOME/other/";
            download = "$HOME/downloads/";
            videos = "$HOME/other/";
            music = "$HOME/music/";
            pictures = "$HOME/pictures/";
            desktop = "$HOME/other/";
            publicShare = "$HOME/other/";
            templates = "$HOME/other/";
        };
        xdg.mimeApps = rec {
            enable = true;
            associations.added = defaultApplications;
            defaultApplications = {
                "inode/directory" = cfg.file-manager;

                "x-scheme-handler/http" = cfg.browser;
                "x-scheme-handler/https" = cfg.browser;
                "application/xhtml+xml" = cfg.browser;
                "text/html" = cfg.browser;

                #"x-scheme-handler/magnet" = torrent;
                "application/pdf" = cfg.browser;

                "image/jpeg" = cfg.image-viewer;
                "image/bmp" = cfg.image-viewer;
                "image/gif" = cfg.image-viewer;
                "image/jpg" = cfg.image-viewer;
                "image/pjpeg" = cfg.image-viewer;
                "image/png" = cfg.image-viewer;
                "image/tiff" = cfg.image-viewer;
                "image/webp" = cfg.image-viewer;
                "image/x-bmp" = cfg.image-viewer;
                "image/x-gray" = cfg.image-viewer;
                "image/x-icb" = cfg.image-viewer;
                "image/x-ico" = cfg.image-viewer;
                "image/x-png" = cfg.image-viewer;
                "image/x-portable-anymap" = cfg.image-viewer;
                "image/x-portable-bitmap" = cfg.image-viewer;
                "image/x-portable-graymap" = cfg.image-viewer;
                "image/x-portable-pixmap" = cfg.image-viewer;
                "image/x-xbitmap" = cfg.image-viewer;
                "image/x-xpixmap" = cfg.image-viewer;
                "image/x-pcx" = cfg.image-viewer;
                "image/svg+xml" = cfg.image-viewer;
                "image/svg+xml-compressed" = cfg.image-viewer;
                "image/vnd.wap.wbmp" = cfg.image-viewer;
                "image/x-icns" = cfg.image-viewer;

                "video/mp4" = cfg.video-player;
                "video/mpeg" = cfg.video-player;
                "video/quicktime" = cfg.video-player;
                "video/x-msvideo" = cfg.video-player;
                "video/x-ms-asf" = cfg.video-player;
                "video/x-ms-wmv" = cfg.video-player;
                
            };
        };
    };
}
