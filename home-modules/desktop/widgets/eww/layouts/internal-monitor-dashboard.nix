let
    output = "eDP-1";
in {
    co2_chart = {
        key = "co2"; type = "chart"; title = "CO₂"; icon = "lungs";
        inherit output; x = 16; y = 14; width = 320; height = 160;
    };
    temperature_chart = {
        key = "temperature"; type = "chart"; title = "Temperature"; icon = "temperature";
        inherit output; x = 352; y = 14; width = 384; height = 160;
    };
    humidity_value = {
        key = "humidity"; type = "value"; title = "Humidity"; icon = "droplet";
        inherit output; x = 752; y = 14; width = 192; height = 160;
    };
    today_power = {
        key = "today_power"; type = "value"; title = "Energy"; icon = "bolt";
        inherit output; x = 16; y = 190; width = 192; height = 160;
    };
    power_chart = {
        key = "power"; type = "chart"; title = "Active power"; icon = "plug";
        inherit output; x = 224; y = 190; width = 416; height = 160;
    };
}
