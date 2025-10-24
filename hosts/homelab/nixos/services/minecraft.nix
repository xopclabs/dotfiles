{ config, pkgs, ... }:

{
    # Not using declarative since I want to keep whitelist declarative
    # but still store server.properties in git somehow
    sops.secrets."minecraft/server-properties" = {
        path = "${config.services.minecraft-server.dataDir}/server.properties";
        owner = "minecraft";
        group = "minecraft";
        mode = "0600";
        sopsFile = ../../../../secrets/hosts/${config.networking.hostName}.yaml;
    };
    services.minecraft-server = {
        enable = false;
        package = pkgs.papermc;
        eula = true;
        openFirewall = true;

        # JVM options for performance
        jvmOpts = "-Xms2048M -Xmx4096M";
    };
}

