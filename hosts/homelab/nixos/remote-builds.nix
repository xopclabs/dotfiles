{ config, pkgs, inputs, ... }:

{
    nix = {
        buildMachines = [{
            hostName = "localhost";
            system = "x86_64-linux";
            maxJobs = 12;
            speedFactor = 4;
            supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
        }];
        distributedBuilds = true;
    };
    nix.settings = {
        trusted-users = [ "nix-builder" ];
        allowed-users = [ "nix-builder" ];
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