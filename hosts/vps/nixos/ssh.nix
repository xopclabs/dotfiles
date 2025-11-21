{ config, pkgs, inputs, ... }:

{
    services.openssh = {
        enable = true;
        settings = {
            PermitRootLogin = "no";
            PasswordAuthentication = false;
        };
    };
    users.users.${config.metadata.user}.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/qy9bDzKgpuIyHMalEPhMFgJ9hamF2LhR0kfk+2Et7"
    ];
    users.users.root.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/qy9bDzKgpuIyHMalEPhMFgJ9hamF2LhR0kfk+2Et7"
    ];
}
