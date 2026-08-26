{ config, pkgs, inputs, ... }:

{
    nix.settings = {
        trusted-users = [ "remote-builder" ];
        allowed-users = [ "remote-builder" ];
        extra-platforms = [ "i686-linux" ];
        # 3900X 12c/24t, 48GB, plus Docker/ZFS on this box.
        # Two jobs × 12 cores: a valve kernel gets -j12 (SMT barely helps gcc),
        # a second derivation can run beside it, ~24GB RAM each.
        # Do not leave `cores` unset: default 0 means every job runs `make -j24`,
        # and four of those OOMs this machine.
        max-jobs = 2;
        cores = 12;
        substituters = [
            "https://jovian.cachix.org"
            "https://chaotic-nyx.cachix.org"
        ];
        trusted-public-keys = [
            "jovian.cachix.org-1:8Vq4Txku6VZIRhYrHYki3Ab9XHJRoWmdYqMqj4rB/Uc="
            "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
        ];
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