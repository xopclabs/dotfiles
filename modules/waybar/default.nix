{ pkgs, lib, config, inputs, ... }:

with lib;
let 
    cfg = config.modules.waybar;
in {
    options.modules.waybar = { enable = mkEnableOption "waybar"; };
    imports = [ ./icons.nix ];
    config = mkIf cfg.enable {
        programs.waybar = {
            enable = true;
            package = inputs.waybar.packages.${pkgs.system}.default;
            systemd.enable = true;
            systemd.target = "graphical-session.target";
            settings = {
                mainBar = let
                    drawer-config = {
                        transition-duration = 250;
                        children-class = "";
                        transition-left-to-right = false;
                    };
                in {
                    layer = "top";
                    position = "left";
                    modules-left = [
                        "hyprland/workspaces"
                    ];
                    modules-right = [
                        "tray"
                        "group/group-status"
                        "group/group-control"
                        "clock"
                        "group/group-power"
                    ];

                    "group/group-status" = {
                        orientation = "inherit";
                        modules = [
                            "hyprland/language"
                            "network"
                            "battery"
                        ];
                    };

                    "group/group-control" = {
                        orientation = "inherit";
                        modules = [
                            "group/group-audio"
                            "group/group-backlight"
                        ];
                    };

                    "group/group-power" = {
                        orientation = "inherit";
                        drawer = drawer-config;
                        modules = [
                            "custom/power"
                            "custom/quit"
                            "custom/lock"
                            "custom/reboot"
                        ];
                    };

                    "group/group-audio" = {
                        orientation = "inherit";
                        drawer = drawer-config;
                        modules = [
                            "pulseaudio"
                            "pulseaudio/slider"
                        ];
                    };

                    "group/group-backlight" = {
                        orientation = "inherit";
                        drawer = drawer-config;
                        modules = [
                            "backlight"
                            "backlight/slider"
                        ];
                    };

                    "hyprland/workspaces" = {
                        show-special = true;
                        all-outputs = false;
                        format = "<span line_height=\"1.25\">{icon}</span>\n<span line_height=\"1\">{windows}</span>";
                        format-window-separator = "\n";
                        format-icons = {
                            "1" = "󰯫"; "2" = "󰰞"; "3" = "󰰡"; "4" = "󰰤";
                            "5" = "󰰛"; "6" = "󰰭"; "7" = "󰯺"; "8" = "󰰘";
                            "scratchpad" = "󰬚";
                        };
                        justify = "center";
                    };

                    "hyprland/language" = {
                        format = "{short}";
                        tooltip = false;
                    };

                    pulseaudio = {
                        scroll-step = 2;
                        format = "{icon}";
                        format-muted = "󰝟";
                        format-source = "";
                        format-source-muted = "";
                        format-icons = {
                            "speaker" = "󰕾";
                            "hdmi" = "󰓃";
                            "headphone" = "󰋋";
                            "hands-free" = "󰋎";
                            "headset" = "󰋎";
                            "phone" = "";
                            "portable" = "";
                            "car" = "";
                            "default" = "󰕾";
                        };
                        on-click-right = "pavucontrol";
                        on-click = "swayosd-client --output-volume=mute-toggle";
                        on-scroll-up = "swayosd-client --output-volume=raise";
                        on-scroll-down = "swayosd-client --output-volume=lower";
                    };

                    "pulseaudio/slider" = {
                        orientation = "vertical";
                    };

                    clock = {
                        tooltip-format = "<big>{:%B %d}</big>\n<tt><small>{calendar}</small></tt>";
                        format = "{:%H\n%M}";
                    };

                    tray = {
                        icon-size = 18;
                    };

                    battery = {
                        format = "{icon}";
                        format-charging = "";
                        format-icons = [
                            "" "" "" "" ""
                        ];
                        tooltip-format = "{capacity:0>2}%";
                        states = {
                            warning = 20;
                            good = 70;
                            great = 98;
                            full = 100;
                        };
                    };

                    "custom/quit" = {
                        format = "󰗼";
                        tooltip = false;
                        on-click = "hyprctl dispatch exit";
                    };

                    "custom/lock" = {
                        format = "󰍁";
                        tooltip = false;
                        on-click = "hyprlock";
                    };

                    "custom/reboot" = {
                        format = "󰜉";
                        tooltip = false;
                        on-click = "systemctl reboot";
                    };

                    "custom/power" = {
                        format = "";
                        tooltip = false;
                        on-click = "shutdown now";
                    };

                    network = {
                        format = "{icon}";
                        format-icons = [ "󰤟" "󰤢" "󰤥" "󰤨" ];
                        format-ethernet = "󰈀";
                        format-disconnected = "󰤮";
                        format-disabled = "";
                        tooltip-format = "{essid}\n{ipaddr}";
                        tooltip-format-disconnected = "Not Connected";
                        tooltip-format-disabled = "Disabled";
                        on-click = "kitty --title nmtui -e nmtui";
                    };

                    backlight = {
                        tooltip = false;
                        format = "{icon}";
                        format-icons = [ "󰃞" "󰃟" "󰃠" ];
                    };

                    "backlight/slider" = {
                        orientation = "vertical";
                    };

                    "custom/os" = {
                        format = "󱄅";
                        tooltip = false;
                        on-click = "launcher";
                    };
                };
            };

            style = with config.colorScheme.palette; let
                font-family = "Mononoki Nerd Font";
                font-size = "14pt";
                workspaces-inside-gap = "0.1rem";
                workspaces-gap = "0.3rem";
                gap = "0.3rem";  
                inside-gap = "0.3rem";
            in ''
            /* nix-colors */
            @define-color dynamic-blue         #${base0F};
            @define-color dynamic-purple       #${base0E};
            @define-color dynamic-lightblue    #${base0D};
            @define-color dynamic-lighterblue  #${base0C};
            @define-color dynamic-teal         #${base07};
            @define-color dynamic-green        #${base0B};
            @define-color dynamic-yellow       #${base0A};
            @define-color dynamic-orange       #${base09};
            @define-color dynamic-red          #${base08};
            @define-color dynamic-darkerwhite  #${base04};
            @define-color dynamic-darkwhite    #${base05};
            @define-color dynamic-white        #${base06};
            @define-color dynamic-black        #${base00};
            @define-color dynamic-lightblack   #${base01};
            @define-color dynamic-lighterblack #${base02};

            /* UI colors */
            @define-color foreground @dynamic-white;
            @define-color background @dynamic-black;
            @define-color accent @dynamic-blue;

            /* Status colors */
            @define-color warning @dynamic-orange;
            @define-color critical @dynamic-red;

            /* Module colors */
            @define-color workspaces-background @dynamic-lightblack;
            @define-color workspaces-hover-background @lightblack;
            @define-color workspaces-visible @dynamic-purple;
            @define-color workspaces-active @accent;

            @define-color audio-color @dynamic-purple;
            @define-color backlight-color @dynamic-yellow;

            @define-color language-color @dynamic-darkerwhite;
            @define-color network-color @dynamic-lighterblue;
            @define-color battery-color @dynamic-green;

            @define-color power-color @dynamic-red;
            @define-color reboot-color @dynamic-green;
            @define-color lock-color @dynamic-yellow;
            @define-color quit-color @dynamic-purple;

            /* Reset all styles */
            * {
                border: none;
                border-radius: 0;
                min-height: 0;
                margin: 0;
                padding: 0;
                box-shadow: none;
                text-shadow: none;
                -gtk-icon-shadow: none;
            }

            /* The whole bar */
            #waybar {
                background: @background;
                color: @foreground;
                font-family: "${font-family}";
                font-size: ${font-size};
                font-weight: bold;
                margin: 0px;
            }

            /* Each module */
            #workspaces,
            #tray,
            #group-status,
            #language,
            #network,
            #battery,
            #group-control,
            #pulseaudio,
            #backlight,
            #clock,
            #group-power,
            #custom-power,
            #custom-lock,
            #custom-quit,
            #custom-reboot {
                margin-left: 0px;
                margin-right: 0px;
            }

            /* Each module in order of appearance */
            /* Top */
            #workspaces button {
                padding-top: ${workspaces-inside-gap};
                padding-bottom: ${workspaces-inside-gap}; 
                font-size: ${font-size};
                color: @text;
                margin: ${workspaces-gap};
                background-color: @workspaces-background;
            }
            #workspaces button.visible {
                background-color: @workspaces-visible;
            }
            #workspaces button.active {
                background-color: @workspaces-active;
            }
            #workspaces button.urgent {
                background-color: @warning;
            }
            #workspaces button:hover {
                text-shadow: inherit;
                transition: none;
                border: none;
                background: none;
                background-color: @workspaces-hover-background;
            }
            #workspaces button.active:hover {
                background-color: @workspaces-active;
                color: @workspaces-background;
            }


            /* Bottom */
            #tray, 
            #group-status,
            #group-control,
            #clock,
            #group-power {
                background-color: @dynamic-lightblack;
                margin: ${gap};
            }
            #group-status *,
            #group-control *,
            #group-power * {
                margin: 0px;
                padding: ${inside-gap};
            }
                
            /* Status group*/
            #language {
                color: @language-color;
            }

            #network {
                color: @network-color;
            }
            #network.disconnected {
                color: @warning;
            }

            #battery { color: @battery-color; }
            #battery.warning { color: @critical; }
            #battery.good { color: @warning; }
            #battery.great { color: @battery-color; }
            #battery.full { color: @gbattery-color; }
            #battery.warning.discharging {
                color: @warning;
            }
            #battery.critical.discharging {
                animation-timing-function: linear;
                animation-iteration-count: infinite;
                animation-direction: alternate;
                animation-name: blink-critical;
                animation-duration: 1s;
            }


            /* Control group */
            #pulseaudio-slider, 
            #pulseaudio-slider *, 
            #group-audio { margin: 0; padding: 0; }
            #pulseaudio-slider highlight { background-color: @audio-color; }
            #pulseaudio { color: @audio-color; }

            #backlight-slider, 
            #backlight-slider *, 
            #group-backlight { margin: 0; padding: 0; }
            #backlight { color: @backlight-color; }
            #backlight-slider highlight { background-color: @backlight-color; }

            /* Power group */
            #custom-power { color: @power-color; padding-bottom: ${inside-gap}; }
            #custom-reboot { color: @reboot-color; }
            #custom-lock { color: @lock-color; }
            #custom-quit { color: @quit-color; }

            /* Slider-related CSS */
            slider {
                min-height: 0px;
                min-width: 0px;
                opacity: 0;
                background-image: none;
                border: none;
                box-shadow: none;
            }

            trough {
                min-height: 80px;
                min-width: 10px;
                border-radius: 5px;
            }

            highlight {
                min-width: 10px;
                border-radius: 5px;
            }
            '';
        };
    };
}
