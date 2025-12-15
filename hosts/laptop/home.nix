{ config, lib, pkgs, inputs, ... }:

{
    imports = [
        inputs.sops-nix.homeManagerModules.sops
    ];

    # Let home-manager manage itself
    programs.home-manager.enable = true;

    # Sops for home-manager configuration
    sops = {
        defaultSopsFile = ../../secrets/shared/personal.yaml;
        age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
    };

    # Generate age key from SSH key for sops CLI usage
    systemd.user.services.sops-age-key-setup = {
        Unit = {
            Description = "Generate age key from SSH key for sops CLI";
            After = [ "default.target" ];
        };
        Service = {
            Type = "oneshot";
            ExecStart = let
                script = pkgs.writeShellScript "sops-age-key-setup" ''
                    SSH_KEY="${config.home.homeDirectory}/.ssh/id_ed25519"
                    AGE_KEY_DIR="${config.home.homeDirectory}/.config/sops/age"
                    AGE_KEY_FILE="$AGE_KEY_DIR/keys.txt"

                    if [ ! -f "$SSH_KEY" ]; then
                        echo "SSH key not found at $SSH_KEY"
                        exit 1
                    fi

                    ${pkgs.coreutils}/bin/mkdir -p "$AGE_KEY_DIR"
                    ${pkgs.ssh-to-age}/bin/ssh-to-age -private-key -i "$SSH_KEY" > "$AGE_KEY_FILE"
                    ${pkgs.coreutils}/bin/chmod 600 "$AGE_KEY_FILE"
                    echo "Age key generated at $AGE_KEY_FILE"
                '';
            in "${script}";
            RemainAfterExit = true;
        };
        Install = {
            WantedBy = [ "default.target" ];
        };
    };
} 
