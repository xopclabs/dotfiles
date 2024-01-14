{ pkgs, lib, config, ... }:

with lib;
let 
    cfg = config.modules.xdg;
    browser = "firefox.desktop";
    file-manager = "org.gnome.Nautilus.desktop";
    image-viewer = "org.gnome.Loupe.desktop";
    torrent = "transmission-gtk.desktop";
in {
    options.modules.xdg = { enable = mkEnableOption "xdg"; };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
            gnome.nautilus
            loupe
            transmission-gtk
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
                "inode/directory" = file-manager;

                "x-scheme-handler/http" = browser;
                "x-scheme-handler/https" = browser;
                "application/xhtml+xml" = browser;
                "text/html" = browser;

                "x-scheme-handler/magnet" = torrent;
                "application/pdf" = browser;

                "image/jpeg" = image-viewer;
                "image/bmp" = image-viewer;
                "image/gif" = image-viewer;
                "image/jpg" = image-viewer;
                "image/pjpeg" = image-viewer;
                "image/png" = image-viewer;
                "image/tiff" = image-viewer;
                "image/webp" = image-viewer;
                "image/x-bmp" = image-viewer;
                "image/x-gray" = image-viewer;
                "image/x-icb" = image-viewer;
                "image/x-ico" = image-viewer;
                "image/x-png" = image-viewer;
                "image/x-portable-anymap" = image-viewer;
                "image/x-portable-bitmap" = image-viewer;
                "image/x-portable-graymap" = image-viewer;
                "image/x-portable-pixmap" = image-viewer;
                "image/x-xbitmap" = image-viewer;
                "image/x-xpixmap" = image-viewer;
                "image/x-pcx" = image-viewer;
                "image/svg+xml" = image-viewer;
                "image/svg+xml-compressed" = image-viewer;
                "image/vnd.wap.wbmp" = image-viewer;
                "image/x-icns" = image-viewer;
            };
        };
    };
}
