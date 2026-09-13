{ config, lib, pkgs, ... }:

with lib;
let
    sshKeyPaths = config.sops.age.sshKeyPaths;
in
{
    # sops-nix uses sshKeyPaths at activation, whereas the standalone sops CLI
    # requires a native age identity at its conventional location.
    config = mkIf (sshKeyPaths != []) {
        systemd.user.services.sops-age-key-setup = {
            Unit = {
                Description = "Derive a SOPS age identity from the configured SSH key";
                After = [ "default.target" ];
            };
            Service = {
                Type = "oneshot";
                ExecStart = let
                    script = pkgs.writeShellScript "sops-age-key-setup" ''
                        SSH_KEY="${head sshKeyPaths}"
                        AGE_KEY_DIR="${config.home.homeDirectory}/.config/sops/age"
                        AGE_KEY_FILE="$AGE_KEY_DIR/keys.txt"

                        test -f "$SSH_KEY"
                        ${pkgs.coreutils}/bin/mkdir -p "$AGE_KEY_DIR"
                        ${pkgs.ssh-to-age}/bin/ssh-to-age -private-key -i "$SSH_KEY" > "$AGE_KEY_FILE"
                        ${pkgs.coreutils}/bin/chmod 600 "$AGE_KEY_FILE"
                    '';
                in "${script}";
                RemainAfterExit = true;
            };
            Install.WantedBy = [ "default.target" ];
        };
    };
}
