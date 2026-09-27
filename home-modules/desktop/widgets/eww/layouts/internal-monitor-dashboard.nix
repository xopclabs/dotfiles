let
    output = "eDP-1";
in {
    # The open cells are reserved for future music, weather and controls.
    co2_chart = {
        key = "co2"; type = "chart"; title = "CO₂"; icon = "lungs";
        inherit output;
        position = { row = 0; col = 0; };
        size = { rows = 2; cols = 4; };
    };
    temperature_chart = {
        key = "temperature"; type = "chart"; title = "Temperature"; icon = "temperature";
        inherit output;
        position = { row = 0; col = 4; };
        size = { rows = 2; cols = 7; };
    };

    today_power = {
        key = "today_power"; type = "value"; title = "Today"; icon = "bolt";
        inherit output;
        position = { row = 2; col = 0; };
        size = { rows = 2; cols = 2; };
    };
    power_chart = {
        key = "power"; type = "chart"; title = "Active power"; icon = "plug";
        inherit output;
        position = { row = 2; col = 2; };
        size = { rows = 2; cols = 6; };
    };

    humidity_value = {
        key = "humidity"; type = "value"; title = "Humidity"; icon = "droplet";
        inherit output;
        position = { row = 4; col = 0; };
        size = { rows = 2; cols = 2; };
    };
}
