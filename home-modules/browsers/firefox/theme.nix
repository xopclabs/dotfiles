{ inputs, lib, config, pkgs, ... }:
with lib;
let
    cfg = config.modules.firefox;
in {
    config = {
        programs.firefox = {
            profiles."${config.home.username}" = {
                userChrome = ''
                    @import "chrome.css";
                '';
                userContent = ''
                    @import "content.css";
                '';
            };
        };
        home.file.".mozilla/firefox/${config.home.username}/chrome" = {
            recursive = true;
            source = ./theme;
        };
        home.file.".mozilla/firefox/${config.home.username}/chrome/colors.css".text = with config.colorScheme.palette; ''
            :root {
            /*Dark*/
            --dark_color1: #${base00};
            --dark_color2: #${base01};
            --dark_color3: #${base02};
            --dark_color4: #${base03};

            --light_color1: #${base04};
            --light_color2: #${base05};
            --light_color3: #${base06};
            --light_color4: #${base07};

            --word_color1: #${base06};
            --word_color2: #${base0E};
            --word_color3: #${base06};
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
                --base_color1: #${base00};
                --base_color2: #${base0E};
                --base_color3: #${base02};
                --base_color4: #${base03};

                --outer_color1: #${base04};
                --outer_color2: #${base05};
                --outer_color3: #${base06};

                --orbit_color: #${base04};
            }
            }
        '';
        home.file."dotfiles/home-modules/browsers/firefox/theme/treestyletab.css".text = with config.colorScheme.palette; ''
                :root {
                /* This value should be updated here and in the userChrome.css */
                    --tst-sidepanel-hide-delay: 0s;
                }

                /* Hide border on tab bar, force its state to 'scroll', adjust margin-left for width of scrollbar. */
                #tabbar {
                    border: 0;
                    scrollbar-width: none;
                    overflow: scroll !important;
                    margin-top:  0 !important;
                }

                /* resolve extra space for scrollbar (scrollbar is hidden by this script) */
                .on-scrollbar-area #tabbar {
                    --shift-tabs-for-scrollbar-distance: 0px;
                }

                /* Include 'reveal' animation ... stagers by level */
                #tabbar .tab {
                    transition: 0.1s margin-top, 0.2s 0.1s visibility;
                }
                #tabbar tab-item-substance {
                    transition: 0.2s 0.1s margin-left;
                }

                /* delay transitions on open */
                #tabbar:not(:hover) tab-item-substance {
                    margin-left: 0;
                }

                /* animate twisty reveal */
                #tabbar .tab .twisty {
                    transition: 0.2s margin;
                }

                /* general tabs */
                .tab {
                    background-color: var(--theme-colors-frame);
                }
                .tab,
                .tab.pinned {
                    height: 2.8em;
                }

                /* Push tab labels slightly to the right so they're completely hidden in collapsed state, but still look fine while expanded. */
                .tab .label {
                    margin-left: 2em;
                }

                /* fix closebox */
                .tab .closebox {
                    margin-left:  0;
                }

                .tab .counter {
                    margin-left:  auto;
                    display: inline-block !important;
                }

                /* Hide .twisty and adjust margins so favicons have 7px on left. */
                #tabbar:not(:hover) .tab .twisty {
                    visibility: hidden;
                    margin-left: -5px;
                    transition-delay: var(--tst-sidepanel-hide-delay);
                }


                /* hide closebox unless needed */
                .tab:not(:hover) .closebox {
                    visibility: hidden;
                }

                /* Hide sound playing/muted button. */
                .sound-button {
                    margin-left: 0;
                    display: inline-block;
                    visibility: collapse;
                }

                .tab.audible .sound-button {
                    visibility: visible;
                    margin-left: 0.25em;
                }

                .tab:not([data-child-ids]) .counter {
                /* visibility: hidden; */
                }

                tab-item:not(.subtree-collapsed) .counter {
                    visibility: hidden;
                } 

                /* active tab */
                .tab.active {
                    background-color: var(--theme-colors-popup) !important;
                }

                tab-item.active .highlighter::before {
                    background-color: #fffd !important;
                }

                .tab:hover,
                .tab.active:hover {
                    background-color: inherit;
                }
                .tab.active .label {
                    font-weight: bold;
                    color: var(--theme-clors-icons) !important;
                }
                .tab .label,
                .tab.active .label {
                    border-bottom:  1px solid transparent;
                }
                .tab:hover .label,
                .tab.active:hover .label {
                    border-bottom:  1px dotted;
                    min-width:  0 !important;
                    flex-shrink:  1 !important;
                    flex-grow:  unset !important;
                }

                /* pending / unloaded tabs 
                .tab.discarded {
                    background-color: var(--theme-colors-frame);
                }
                .tab.discarded .label {
                    color: #${base00}CC !important;
                }
                .tab.discarded:hover .label {
                    color: var(--theme-colors-frame) !important;
                }
                */

                /* Adjust style for tab that has sound playing. */
                .tab.sound-playing .favicon::after,
                .tab.muted .favicon::after {
                    content: '🔊';
                    z-index: var(--favicon-base-z-index);
                    position: absolute;
                    font-size: 0.5em;
                    bottom: -0.35em;
                    right: -0.7em;
                }

                /* Adjust style for tab that is muted. */
                .tab.muted .favicon::after {
                    content: '🔇';
                }

                /* Pinned tabs: */
                /* Hide all non-active pinned tabs (these are included in top-bar instead) */
                .tab.pinned {
                    position: relative;
                    max-width: none;
                    width: auto;
                    top: 0 !important;
                    left: 0 !important;
                }

                .tab.pinned .label,
                .tab.pinned .label-content {
                    opacity: 1;
                    position: unset;
                    padding-bottom: 0;
                }
                .tab.pinned .sound-button {
                    position: relative;
                    transform: none;
                }
                .tab.pinned .twisty {
                    display: block;
                    min-width: none;
                    width: auto;
                }
                tab-item.active .background, tab-item.active tab-item-substance:hover .background, tab-item.bundled-active .background, tab-item.bundled-active tab-item-substance:hover .background, .mutiple-highlighted > tab-item.highlighted .background, .mutiple-highlighted > tab-item.highlighted tab-item-substance:hover .background {
                    box-shadow: unset;
                    outline: unset;
                }

                #tabbar-container {
                    margin-left: -5px;
                }
        '';
    };
}
