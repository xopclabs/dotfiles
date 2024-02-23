{ inputs, lib, config, pkgs, ... }:
with lib;
let
    cfg = config.modules.firefox;
in {
    imports = [
        ./theme.nix
    ];
    options.modules.firefox = { enable = mkEnableOption "firefox"; };
    config = mkIf cfg.enable {
        home.packages = with pkgs; [
             firefox
        ];
        programs.firefox = {
            enable = true;
            # Privacy about:config settings
            profiles.xopc = {
                isDefault = true;
                # install extensions from nur
                extensions = with pkgs.nur.repos.rycee.firefox-addons; [
                        decentraleyes
                        ublock-origin
                        clearurls
                        sponsorblock
                        bitwarden
                        vimium
                        tree-style-tab
                    ];
                settings = {
                    "browser.send_pings" = false;
                    "browser.urlbar.speculativeConnect.enabled" = false;
                    "dom.event.clipboardevents.enabled" = true;
                    "media.navigator.enabled" = false;
                    "network.http.referer.XOriginPolicy" = 2;
                    "network.http.referer.XOriginTrimmingPolicy" = 2;
                    "beacon.enabled" = false;
                    "browser.safebrowsing.downloads.remote.enabled" = false;
                    "network.IDN_show_punycode" = true;
                    "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";
                    "app.shield.optoutstudies.enabled" = false;
                    "dom.security.https_only_mode_ever_enabled" = true;
                    "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
                    "browser.toolbars.bookmarks.visibility" = "never";
                    "geo.enabled" = false;
                    # Search engine
                    "browser.search.defaultenginename" = "DuckDuckGo";
                    "browser.search.order.1" = "DuckDuckGo";
                    # Disable telemetry
                    "browser.newtabpage.activity-stream.feeds.telemetry" = false;
                    "browser.ping-centre.telemetry" = false;
                    "browser.tabs.crashReporting.sendReport" = false;
                    "devtools.onboarding.telemetry.logged" = false;
                    "toolkit.telemetry.enabled" = false;
                    "toolkit.telemetry.unified" = false;
                    "toolkit.telemetry.server" = "";
                    # Disable Pocket
                    "browser.newtabpage.activity-stream.feeds.discoverystreamfeed" = false;
                    "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
                    "browser.newtabpage.activity-stream.section.highlights.includePocket" = false;
                    "browser.newtabpage.activity-stream.showSponsored" = false;
                    "extensions.pocket.enabled" = false;
                    # Disable prefetching
                    "network.dns.disablePrefetch" = true;
                    "network.prefetch-next" = false;
                    # Disable JS in PDFs
                    "pdfjs.enableScripting" = false;
                    # Harden SSL 
                    "security.ssl.require_safe_negotiation" = true;
                    # Extra
                    "identity.fxaccounts.enabled" = false;
                    "browser.search.suggest.enabled" = false;
                    "browser.urlbar.shortcuts.bookmarks" = false;
                    "browser.urlbar.shortcuts.history" = true;
                    "browser.urlbar.shortcuts.tabs" = false;
                    "browser.urlbar.suggest.bookmark" = false;
                    "browser.urlbar.suggest.engines" = false;
                    "browser.urlbar.suggest.history" = true;
                    "browser.urlbar.suggest.openpage" = false;
                    "browser.urlbar.suggest.topsites" = false;
                    "browser.uidensity" = 1;
                    "media.autoplay.enabled" = false;
                    "media.peerconnection.enabled" = true;
                    "toolkit.zoomManager.zoomValues" = ".8,.90,.95,1,1.1,1.2";
                    "privacy.firstparty.isolate" = true;
                    "network.http.sendRefererHeader" = 0;
                };
            };
        };
    };
}
