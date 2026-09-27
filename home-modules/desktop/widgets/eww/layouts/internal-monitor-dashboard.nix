let
    output = "eDP-1";
in {
    # The open cells are reserved for future music, weather and controls.
    co2_chart = {
        source = "co2"; template = "chart"; title = "CO₂"; icon = "lungs";
        inherit output;
        position = { row = 0; col = 0; };
        size = { rows = 2; cols = 4; };
    };
    temperature_chart = {
        source = "temperature"; template = "chart"; title = "Temperature"; icon = "temperature";
        inherit output;
        position = { row = 0; col = 4; };
        size = { rows = 2; cols = 6; };
    };

    today_power = {
        source = "today_power"; template = "value"; title = "Today"; icon = "bolt";
        inherit output;
        position = { row = 2; col = 0; };
        size = { rows = 1; cols = 2; };
    };
    prior_avg_power = {
        source = "prior_avg_power"; template = "value"; title = "30d avg · now"; icon = "bolt";
        inherit output;
        position = { row = 3; col = 0; };
        size = { rows = 1; cols = 2; };
    };
    power_chart = {
        source = "power"; template = "chart"; title = "Active power"; icon = "plug";
        inherit output;
        position = { row = 2; col = 2; };
        size = { rows = 2; cols = 6; };
    };

    humidity_value = {
        source = "humidity"; template = "value"; title = "Humidity"; icon = "droplet";
        inherit output;
        position = { row = 4; col = 0; };
        size = { rows = 2; cols = 2; };
    };
}
