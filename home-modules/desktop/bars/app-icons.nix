# App id or title:Needle -> Tabler (Noctalia) and Nerd (Waybar) glyphs.
{ lib }:

let
    inherit (lib)
        attrNames
        concatMap
        hasInfix
        hasPrefix
        listToAttrs
        mapAttrs
        mapAttrs'
        optional
        removePrefix
        stringLength
        substring
        toUpper
        ;

    targets = {
        firefox = { tabler = "brand-firefox"; nerd = "󰈹"; };
        floorp = { tabler = "brand-firefox"; nerd = "󰈹"; };
        kitty = { tabler = "terminal-2"; nerd = ""; };
        vncviewer = { tabler = "device-desktop"; nerd = "󰢹"; };
        cursor = { tabler = "brand-vscode"; nerd = "󰨞"; };
        code = { tabler = "brand-vscode"; nerd = "󰨞"; };
        "code-url-handler" = { tabler = "brand-vscode"; nerd = "󰨞"; };
        "org.telegram.desktop" = { tabler = "brand-telegram"; nerd = ""; };
        "libreoffice-calc" = { tabler = "table"; nerd = "󰈛"; };
        transmission = { tabler = "download"; nerd = ""; };
        "com.obsproject.studio" = { tabler = "video"; nerd = ""; };
        blueman = { tabler = "bluetooth"; nerd = ""; };
        "blueman-manager" = { tabler = "bluetooth"; nerd = ""; };
        "chromium-browser" = { tabler = "brand-chrome"; nerd = ""; };
        yazi = { tabler = "folder"; nerd = ""; };
        ranger = { tabler = "folder"; nerd = ""; };
        mpv = { tabler = "player-play"; nerd = ""; };
        rofi = { tabler = "layout-grid"; nerd = "󱄅"; };
        slack = { tabler = "brand-slack"; nerd = "󰒱"; };
        steam = { tabler = "brand-steam"; nerd = "󰓓"; };
        "com.moonlight_stream.moonlight" = { tabler = "device-gamepad"; nerd = "󰊗"; };
        spotify = { tabler = "brand-spotify"; nerd = ""; };
        blender = { tabler = "brand-blender"; nerd = ""; };
        "org.pulseaudio.pavucontrol" = { tabler = "volume"; nerd = "󰗅"; };
        "title:YouTube" = { tabler = "brand-youtube"; nerd = "󰗃"; };
        "title:Dreaming Spanish" = { tabler = "language"; nerd = ""; };
        "title:Slack" = { tabler = "brand-slack"; nerd = "󰒱"; };
        "title:discord" = { tabler = "brand-discord"; nerd = "󰙯"; };
        "title:Plover" = { tabler = "keyboard"; nerd = "󰼭"; };
        "title:ranger" = { tabler = "folder"; nerd = ""; };
        "title:yazi" = { tabler = "folder"; nerd = ""; };
    };

    default = { tabler = "apps"; nerd = "󱗜"; };

    pick = set: mapAttrs (_: v: v.${set}) targets;

    capitalize = s:
        if s == "" then s
        else toUpper (substring 0 1 s) + substring 1 (stringLength s - 1) s;

    waybarKeys = key:
        if hasPrefix "title:" key then
            [ "title<.*${lib.escapeRegex (removePrefix "title:" key)}.*>" ]
        else
            let escaped = lib.escapeRegex key;
                capped = capitalize key;
            in [ "class<${escaped}>" ]
                ++ optional (!hasInfix "." key && capped != key) "class<${lib.escapeRegex capped}>";

    windowRewrite = listToAttrs (concatMap (key:
        map (wk: { name = wk; value = targets.${key}.nerd; }) (waybarKeys key)
    ) (attrNames targets));
in {
    inherit targets windowRewrite;
    niriWindowRewrite = mapAttrs' (k: v: {
        name = lib.replaceStrings [ "class<" ] [ "app_id<" ] k;
        value = v;
    }) windowRewrite;
    tablerByAppId = pick "tabler";
    nerdByAppId = pick "nerd";
    defaultTabler = default.tabler;
    defaultNerd = default.nerd;
}
