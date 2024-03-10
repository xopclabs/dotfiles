{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.waybar;
in {
    options.modules.waybar = { enable = mkEnableOption "waybar"; };
    config = mkIf cfg.enable {
        programs.waybar = {
            enable = true;
            settings = {
                mainBar = {
                    layer = "top";
                    position = "right";
                    width = 35;
                    output = [
                        "eDP-1"
                    ];
                    modules-left = [
                        "hyprland/workspaces"
                    ];
                    modules-right = [
                        "tray"
                        "hyprland/language#icon"
                        "hyprland/language"
                        "battery#icon"
                        "battery"
                        "pulseaudio#icon"
                        "pulseaudio"
                        "clock#time"
                    ];

                    "hyprland/workspaces" = {
                        persistent-workspaces = {
                            "*" = 8;
                        };
                        format = "{icon}";
                        format-icons = {
                            empty = "";
                            default = "";
                            active = "";
                        };
                    };
                    battery = {
                        interval = 10;
                        states = {
                            warning = 30;
                            critical = 15;
                        };
                        format = "{capacity}%";
                        format-charging = "{capacity}%";
                        format-charging-full = "{capacity}%";
                        format-full = "{capacity}%";
                        format-alt = "{power}W";
                        tooltip = false;
                    };
                    "battery#icon" = {
                        format = "{icon}";
                        format-charging = "";
                        format-charging-full = "";
                        format-full = "{icon}";
                        format-alt = "{icon}";
                        format-icons = [
                            ""
                            ""
                            ""
                            ""
                            ""
                        ];
                    };
                    "clock#date" = {
                        interval = 10;
                        format = "{:%m.%d}";
                        tooltip = false;
                    };
                    "clock#time" = {
                        interval = 10;
                        format = "{:%H\n%M}";
                        tooltip = true;
                        tooltip-format = "{:%m.%d}";
                    };
                    cpu = {
                        interval = 5;
                        tooltip = false;
                        format = "{usage}%";
                        format-alt = "{load}";
                        states = {
                            warning = 70;
                            critical = 90;
                        };
                    };
                    "cpu#icon" = {
                        format = " ";
                    };
                    "hyprland/language" = {
                        format = "{short}";
                        tooltip = false;
                    };
                    "hyprland/language#icon" = {
                        format = "󰌌";
                    };
                    memory = {
                        interval = 5;
                        format = "{used:0.1f}G";
                        states = {
                            warning = 70;
                            critical = 90;
                        };
                        tooltip = false;
                    };
                    "memory#icon" = {
                        format = " ";
                    };
                    "network#icon" = {
                        interval = 10;
                        tooltip = false;
                        format = "{icon}";
                        format-icons = {
                            wifi = [ "󰣴" "󰣶" "󰣸" "󰣺"];
                            ethernet = [" "];
                            disconnected = ["󰣼"];
                        };
                    };
                    pulseaudio = {
                        format = "{volume}%";
                        format-bluetooth = "{volume}%";
                        scroll-step = 1;
                        on-click = "pactl set-sink-mute @DEFAULT_SINK@ toggle";
                        tooltip = false;
                    };
                    "pulseaudio#icon" = {
                        format = "{icon}";
                        format-bluetooth = "{icon}";
                        format-muted = "";
                        format-icons = {
                            headphone = "";
                            hands-free = "";
                            headset = "";
                            phone = "";
                            portable = "";
                            car = "";
                            default = ["" ""];
                        };
                    };
                    temperature = {
                        critical-threshold = 80;
                        interval = 5;
                        format = "{temperatureC}°";
                        tooltip = false;
                    };
                    "temperature#icon" = {
                        format = "{icon}";
                        format-icons = [
                            ""
                            ""
                            ""
                            ""
                            ""
                        ];
                        tooltip = false;
                    };
                    tray = {
                        icon-size = 18;
                    };
                };
            };

            style = with config.colorScheme.palette; ''
/* Keyframes */

@keyframes blink-critical {
	to {
		/*color: @white;*/
		background-color: @critical;
	}
}


/* Styles */
/* Colors (nord) */
@define-color black	#${base00};
@define-color red	#${base08};
@define-color green	#${base0B};
@define-color yellow	#${base0A};
@define-color blue	#${base0C};
@define-color purple	#${base0E};
@define-color aqua	#${base0D};
@define-color gray	#${base01};
@define-color brgray	#${base01};
@define-color brred	#${base08};
@define-color brgreen	#${base0B};
@define-color bryellow	#${base09};
@define-color brblue	#${base0D};
@define-color brpurple	#${base0E};
@define-color braqua	#${base0C};
@define-color white	#${base06};
@define-color bg2	#${base01};


@define-color warning 	@bryellow;
@define-color critical	@red;
@define-color sound	@blue;
@define-color network	@purple;
@define-color memory	@braqua;
@define-color cpu	@blue;
@define-color temp	@brgreen;
@define-color layout	@yellow;
@define-color battery	@green;
@define-color time	@aqua;

/* Reset all styles */
* {
	border: none;
	border-radius: 0;
	min-height: 0;
	margin: 0;
	padding: 0;
	box-shadow: none;
	text-shadow: none;
	icon-shadow: none;
}

/* The whole bar */
#waybar {
	background: @black;
	color: @white;
	font-family: Mononoki Nerd Font;
	font-size: 11pt;
	font-weight: bold;
}

/* Each module */
#battery,
#clock,
#cpu,
#language,
#memory,
#mode,
#network,
#pulseaudio,
#temperature,
#tray,
#backlight,
#idle_inhibitor,
#disk,
#user,
#mpris {
	padding-left: 1pt;
	padding-right: 1pt;
    border-left: @black;
    border-right: @black;
}

/* Each critical module */
#mode,
#memory.critical,
#cpu.critical,
#temperature.critical,
#battery.critical.discharging {
	animation-timing-function: linear;
	animation-iteration-count: infinite;
	animation-direction: alternate;
	animation-name: blink-critical;
	animation-duration: 1s;
}

/* Each warning */
#network.disconnected,
#memory.warning,
#cpu.warning,
#temperature.warning,
#battery.warning.discharging {
	color: @warning;
}

/* And now modules themselves in their respective order */

/* Workspaces stuff */
#workspaces button {
	/*font-weight: bold;*/
	padding-left: 2pt;
	padding-right: 2pt;
	padding-top: 3pt;
	padding-bottom: 3pt;
	color: @white;
	background: @black;
}

/* Contains an urgent window */
#workspaces button.urgent {
	color: @warning;
}

/* Style when cursor is on the button */
#workspaces button:hover {
	background: @bg2;
	color: @white;
}

#pulseaudio {
	background: @sound;
	color: @black;
}

#network {
	background: @network;
	color: @black;
}

#memory {
	background: @memory;
	color: @black;
}

#cpu {
	background: @cpu;
	color: @black;
}

#temperature {
	background: @temp;
	color: @black;
}

#language {
	background: @layout;
	color: @black;
}

#battery {
	background: @battery;
	color: @black;
}

#tray {
	background: @black;
}

#clock {
	background: @time;
	color: @black;
}
            '';
        };
    };
}
