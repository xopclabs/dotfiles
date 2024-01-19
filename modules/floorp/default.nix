{ inputs, lib, config, pkgs, ... }:
with lib;
let
    cfg = config.modules.floorp;
in {
    options.modules.floorp = { enable = mkEnableOption "floorp"; };

    config = mkIf cfg.enable {
        home.packages = with pkgs; [
             floorp
        ];
        programs.floorp = {
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
                userChrome = ''
                    @import "chrome.css";
                '';
                userContent = ''
                    @import "content.css";
                '';
            };
        };
        home.file.".floorp/xopc/chrome" = {
            recursive = true;
            source = ./firefox-elegant;
        };
        home.file.".floorp/xopc/chrome/colors.css".text = ''
            :root {
            /*Dark*/
            --dark_color1: #2e3440;
            --dark_color2: #3b4252;
            --dark_color3: #434c5e;
            --dark_color4: #5e81ac;

            --word_color1: #b48ead;
            --word_color2: #88c0d0;
            --word_color3: #d8dee9;
            }

            /*============== ADAPTIVE THEME ================*/
            /*Dark*/
            @media (prefers-color-scheme: dark) {
            :root {
                --base_color1: var(--dark_color1);
                --base_color2: var(--dark_color2);
                --base_color3: var(--dark_color3);
                --base_color4: var(--dark_color4);

                --outer_color1: var(--word_color1);
                --outer_color2: var(--word_color2);
                --outer_color3: var(--word_color3);

                --orbit_color: var(--light_color3);
            }
            }

            /*================ DARK THEME ================*/
            @media {
            :root[style*="--lwt-accent-color:rgb(12, 12, 13);"] {
                --base_color1: var(--dark_color1);
                --base_color2: var(--dark_color2);
                --base_color3: var(--dark_color3);
                --base_color4: var(--dark_color4);

                --outer_color1: var(--word_color1);
                --outer_color2: var(--word_color2);
                --outer_color3: var(--word_color3);

                --orbit_color: var(--light_color3);
            }
            }

            /*============== PRIVATE THEME ==============*/
            @media {
            :root[privatebrowsingmode="temporary"] {
                --base_color1: #25003e;
                --base_color2: #3c3376;
                --base_color3: #4f499d;
                --base_color4: #625fc4;

                --outer_color1: #e571f0;
                --outer_color2: #d9caf1;
                --outer_color3: #fff5ff;

                --orbit_color: #b39fe3;
            }
            }
        '';
    };
}
