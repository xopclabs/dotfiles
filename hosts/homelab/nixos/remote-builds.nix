{ config, pkgs, inputs, ... }:

{
    nix.settings = {
        trusted-users = [ "remote-builder" ];
        allowed-users = [ "remote-builder" ];
        max-jobs = 4;
        # Allow building 32-bit packages (needed for Steam)
        extra-platforms = [ "i686-linux" ];
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