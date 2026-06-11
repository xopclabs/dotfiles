{ config, lib, inputs, ... }:

{
    imports = [ 
        ../../../nixos-modules/desktop/default.nix
    ];

    # Outbound proxying is handled by homelab.reality.client (see selfhost.nix),
    # which exposes a smart-routed SOCKS/HTTP proxy via the self-hosted VPS exit
    # and configures proxychains.
}
