{ config, pkgs, inputs, ... }:

{
    imports = [
        ../../../nixos-modules/desktop/default.nix
    ];
    
    config.sops.secrets."deck-controller-reconnect/id_ed25519" = {
        sopsFile = ../../../secrets/hosts/deck.yaml;
        key = "deck-controller-reconnect/id_ed25519";
        owner = config.metadata.user;
        mode = "0400";
    };

    config.desktop = {
        wireguard = {
            enable = true;
            peers = {
                home = {
                    enable = true;
                    autostart = false;
                    sopsFile = ../../../secrets/hosts/deck.yaml;
                };
                home_lan = {
                    enable = true;
                    autostart = true;
                    sopsFile = ../../../secrets/hosts/deck.yaml;
                };
                home_pi = {
                    enable = true;
                    autostart = false;
                };
                vps = {
                    enable = true;
                    autostart = false;
                };
            };
        };

        steam = {
            enable = true;
            jovian = {
                enable = true;
                autoStart = true;
                desktopSession = "niri";
                deckyLoader = {
                    enable = false;
                    user = "xopc";
                };
            };
            extraPackages = true;
            hardware = {
                xoneSupport = true;
                joyconSupport = true;
                trackpadDesktop = true;
            };
        };

        deckControllerPassthrough = {
            enable = true;
            role = "exporter";
            exporter = {
                peerAddress = "192.168.1.150";
                disconnectGraceSeconds = 45;
                remoteControl = {
                    enable = true;
                    authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILtyvankFvSvOPNKlIeBOswkvj4RlfRaHCZDq2h3RJuN";
                };
                reconnectTrigger = {
                    enable = true;
                    identityFile = config.sops.secrets."deck-controller-reconnect/id_ed25519".path;
                    hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDj+UaBfIa6icB/CFq3PRV7H48O5bD4UIjyFgBNdORB5";
                };
            };
        };

        lutris.enable = true;
        flatpak.enable = true;
        localsend.enable = true;
        ddcutil.enable = true;
        virtual_webcam.enable = false;
        p81 = {
            enable = true;
            autostart = false;
            splitDns.enable = true;
            sleepResumeRecovery = "async-reset";
            sleepResumeDelaySec = 30;
        };
        ereader_relay = {
            enable = true;
            subdomain = "books.vm.local";
        };

        vanta = {
            enable = true;
        };

        yeetmouse = {
            enable = false; 
            sensitivity = 1.0;
            mode = {
                acceleration = 1.5;
                midpoint = 7.5;
                smoothness = 0.01;
                useSmoothing = false;
            };
        };
    };
}
