{ config, pkgs, inputs, ... }:

{
    services.openssh = {
        enable = true;
        settings = {
            PermitRootLogin = "no";
            PasswordAuthentication = false;

            PerSourcePenalties = "no";

            ClientAliveInterval = 30;
            ClientAliveCountMax = 3;
        };
    };

    # Bots are blocked at the firewall before they can pile onto sshd.
    services.fail2ban.jails.sshd = {
        enabled = true;
        settings = {
            maxretry = 3;
            findtime = "5m";
            bantime = "24h";
        };
    };
    users.users.${config.metadata.user}.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/qy9bDzKgpuIyHMalEPhMFgJ9hamF2LhR0kfk+2Et7"
    ];
    users.users.root.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/qy9bDzKgpuIyHMalEPhMFgJ9hamF2LhR0kfk+2Et7"
    ];
}
