{ config, pkgs, ... }:

{
    services.minecraft-server = {
        enable = true;
        package = pkgs.papermc;
        eula = true;
        openFirewall = true;
        declarative = true;

        serverProperties = {
            server-port = 25565;
            difficulty = 3;
            hardcore = true;
            gamemode = 0;
            max-players = 2;
            motd = "Test!";
            white-list = false;
            enable-command-block = true;
            pvp = true;
            view-distance = 16;
            simulation-distance = 24;
            online-mode = false;
            enable-rcon = false;
        };

        # JVM options for performance
        jvmOpts = "-Xms2048M -Xmx4096M";
    };
}

