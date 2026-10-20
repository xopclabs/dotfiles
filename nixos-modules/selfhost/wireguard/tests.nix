{ nixpkgs, sops-nix }:

let
    lib = nixpkgs.lib;
    evaluate = wireguard: (lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
            ./wireguard.nix
            sops-nix.nixosModules.sops
            {
                options.metadata.hostName = lib.mkOption {
                    type = lib.types.str;
                    default = "laptop";
                };
                config.homelab.wireguard = wireguard;
            }
        ];
    }).config;
    nativeClient = {
        address = "10.13.13.7/24";
        peer.publicKey = "FPVXWSxA7pu4YznVvoqTPdJilNYghEA6Z8bBj69GqQg=";
    };
    cases = {
        disabled = evaluate { };
        server = evaluate { enable = true; };
        native = evaluate { clients.vps = nativeClient; };
        combined = evaluate {
            enable = true;
            clients.vps = nativeClient;
        };
    };
    nativeInterfaces = c: builtins.attrNames c.networking.wireguard.interfaces;
    fileInterfaces = c: builtins.attrNames c.networking.wg-quick.interfaces;
    hasServerBehavior = c: c.networking.nat.enable
        && builtins.elem "wg0" c.networking.firewall.trustedInterfaces
        && c.boot.kernel.sysctl."net.ipv4.ip_forward" == true
        && builtins.elem 51820 c.networking.firewall.allowedUDPPorts;
    noServerBehavior = c: !c.networking.nat.enable
        && !(builtins.elem "wg0" c.networking.firewall.trustedInterfaces)
        && !(c.boot.kernel.sysctl ? "net.ipv4.ip_forward")
        && !(builtins.elem 51820 c.networking.firewall.allowedUDPPorts)
        && !(c.sops.secrets ? "wg/privatekey");
in
assert nativeInterfaces cases.disabled == [ ];
assert fileInterfaces cases.disabled == [ ];
assert noServerBehavior cases.disabled;
assert nativeInterfaces cases.server == [ "wg0" ];
assert hasServerBehavior cases.server;
assert nativeInterfaces cases.native == [ "wg-vps" ];
assert fileInterfaces cases.native == [ ];
assert noServerBehavior cases.native;
assert cases.native.sops.secrets."wg/clients/vps/privatekey".restartUnits == [ "wireguard-wg-vps.service" ];
assert builtins.attrNames cases.native.sops.secrets == [
    "wg/clients/vps/endpoint" "wg/clients/vps/presharedkey" "wg/clients/vps/privatekey"
];
assert nativeInterfaces cases.combined == [ "wg-vps" "wg0" ];
assert fileInterfaces cases.combined == [ ];
assert hasServerBehavior cases.combined;
true
