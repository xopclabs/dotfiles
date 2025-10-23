{ config, pkgs, inputs, ... }:

{
    # Homelab acts as a build server, not a client
    # No buildMachines configuration needed - just build locally
    nix.settings = {
        trusted-users = [ "nix-builder" ];
        allowed-users = [ "nix-builder" ];
        max-jobs = 12;  # Allow multiple parallel builds
    };
    
    # Set up user builder user
    users.users.nix-builder = {
        isNormalUser = true;
	    extraGroups = [ "nixbld" ];
	    openssh.authorizedKeys.keys = [
	        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAFmiLCnm7UOpY9Ak+gxJcsHXBZOfyWiFtl35c49CjjE"
        ];
    };

}