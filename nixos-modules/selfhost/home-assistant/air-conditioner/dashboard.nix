let
    toggle = entity: name: icon: {
        type = "tile";
        inherit entity name icon;
        hide_state = true;
        features_position = "inline";
        features = [ { type = "toggle"; } ];
        tap_action.action = "toggle";
        grid_options = { columns = 6; rows = 1; };
    };
in
{
    title = "Air Conditioner";
    views = [ {
        title = "AC";
        path = "ac";
        type = "sections";
        max_columns = 2;
        sections = [ {
            type = "grid";
            cards = [
                {
                    type = "button";
                    entity = "switch.bodner_ac_power";
                    name = "Power";
                    icon = "mdi:power";
                    icon_height = "24px";
                    show_name = false;
                    show_state = true;
                    tap_action.action = "toggle";
                    grid_options = { columns = 12; rows = 2; };
                }
                {
                    type = "thermostat";
                    entity = "climate.bodner_ac";
                    name = "AC";
                    features = [ {
                        type = "climate-hvac-modes";
                        style = "icons";
                        hvac_modes = [ "auto" "cool" "heat" "dry" "fan_only" ];
                    } {
                        type = "climate-fan-modes";
                        style = "icons";
                    } ];
                    grid_options.columns = 12;
                }
            ];
        } {
            type = "grid";
            cards = [
                (toggle "switch.bodner_ac_silent" "Indication" "mdi:lightbulb-on-outline")
                (toggle "switch.bodner_ac_silence" "Low noise" "mdi:fan-chevron-down")
                (toggle "switch.bodner_ac_turbo" "Turbo" "mdi:fan-plus")
                (toggle "switch.bodner_ac_swing" "Swing" "mdi:swap-vertical")
                {
                    type = "tile";
                    entity = "number.bodner_ac_position";
                    name = "Direction";
                    hide_state = true;
                    icon = "mdi:arrow-up-down";
                    features = [ { type = "numeric-input"; style = "slider"; } ];
                    grid_options.columns = 12;
                }
                {
                    type = "button";
                    entity = "button.bodner_ac_direct";
                    name = "Step";
                    icon = "mdi:arrow-up-down";
                    show_state = false;
                    icon_height = "24px";
                    tap_action = {
                        action = "perform-action";
                        perform_action = "button.press";
                        target.entity_id = "button.bodner_ac_direct";
                    };
                    grid_options.columns = 12;
                }
                {
                    type = "button";
                    name = "Settings";
                    icon = "mdi:cog-outline";
                    icon_height = "24px";
                    tap_action = {
                        action = "navigate";
                        navigation_path = "/air-conditioner/settings";
                    };
                    grid_options.columns = 12;
                }
            ];
        } ];
    } {
        title = "Settings";
        path = "settings";
        subview = true;
        cards = [ {
            type = "entities";
            title = "Vane calibration";
            show_header_toggle = false;
            entities = [ {
                entity = "button.bodner_ac_sync_top_down";
                name = "Just moved down from top";
            } {
                entity = "button.bodner_ac_sync_bottom_up";
                name = "Just moved up from bottom";
            } ];
        } {
            type = "entities";
            title = "Sync controls";
            show_header_toggle = false;
            entities = [
                { entity = "button.bodner_ac_sync_silent_off"; name = "Indication is on"; }
                { entity = "button.bodner_ac_sync_silent_on"; name = "Indication is off"; }
                { entity = "button.bodner_ac_sync_swing_on"; name = "Swing is on"; }
                { entity = "button.bodner_ac_sync_swing_off"; name = "Swing is off"; }
                { entity = "button.bodner_ac_sync_turbo_on"; name = "Turbo is on"; }
                { entity = "button.bodner_ac_sync_turbo_off"; name = "Turbo is off"; }
            ];
        } {
            type = "entities";
            show_header_toggle = false;
            entities = [ {
                entity = "button.bodner_ac_invalidate";
                name = "Reset tracking";
            } ];
        } ];
    } ];
}
