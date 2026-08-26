{ config, pkgs, inputs, ... }:

{
    nix.settings = {
        trusted-users = [ "remote-builder" ];
        allowed-users = [ "remote-builder" ];
        extra-platforms = [ "i686-linux" ];
        max-jobs = 2;
        cores = 12;
    };
    
    # Set up user builder user and group (important!)
    users.groups.remote-builder = {};
    users.users.remote-builder = {
        isNormalUser = true;
	    extraGroups = [ "remote-builder" ];
	    openssh.authorizedKeys.keys = [
	        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAFmiLCnm7UOpY9Ak+gxJcsHXBZOfyWiFtl35c49CjjE"
        ];
    };

}