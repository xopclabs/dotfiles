let
    output = "eDP-1";
in {
    # Remaining open cells are reserved for weather and controls.
    co2_chart = {
        source = "co2"; template = "chart"; title = "CO₂"; icon = "lungs";
        inherit output;
        position = { row = 0; col = 0; };
        size = { rows = 2; cols = 5; };
    };
    temperature_chart = {
        source = "temperature"; template = "chart"; title = "Temperature"; icon = "temperature";
        inherit output;
        position = { row = 0; col = 5; };
        size = { rows = 2; cols = 4; };
    };
    humidity_value = {
        source = "humidity"; template = "value"; title = "Humidity"; icon = "droplet";
        inherit output;
        position = { row = 0; col = 9; };
        size = { rows = 2; cols = 2; };
    };

    today_power = {
        source = "today_power"; template = "value"; title = "Today"; icon = "bolt";
        inherit output;
        position = { row = 2; col = 0; };
        size = { rows = 1; cols = 2; };
    };
    prior_avg_power = {
        source = "prior_avg_power"; template = "value"; title = "Average"; icon = "bolt";
        inherit output;
        position = { row = 3; col = 0; };
        size = { rows = 1; cols = 2; };
    };
    power_chart = {
        source = "power"; template = "chart"; title = "Active power"; icon = "plug";
        inherit output;
        position = { row = 2; col = 2; };
        size = { rows = 2; cols = 5; };
    };

    picker = {
        template = "zap-picker";
        inherit output;
        position = { row = 2; col = 0; };
        size = { rows = 4; cols = 7; };
    };
    music = {
        template = "zap-music";
        inset = 12;
        showAlbum = false;
        inherit output;
        position = { row = 2; col = 7; };
        size = { rows = 4; cols = 4; };
    };
    selection_preview = {
        template = "zap-selection-preview";
        overlay = "music";
        inset = 12;
        showLabel = false;
        inherit output;
        position = { row = 2; col = 7; };
        size = { rows = 4; cols = 4; };
    };
}
