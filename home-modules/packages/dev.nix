{ pkgs, lib, config, inputs, ... }:

with lib;
let
    cfg = config.modules.packages.dev;

    # OpenSpec's flake builds against the now-EOL nodejs_20 (flagged insecure by
    # nixpkgs). Node is only a build-time dep, so rebuild it with a maintained
    # LTS; the runtime `node` comes from nodejs_latest below.
    openspec = (inputs.openspec.packages.${pkgs.stdenv.hostPlatform.system}.default).overrideAttrs (old: {
        nativeBuildInputs = with pkgs; [
            nodejs_22
            npmHooks.npmInstallHook
            pnpmConfigHook
            pnpm_9
        ];
    });
in {
    options.modules.packages.dev = { enable = mkEnableOption "dev"; };
    config = mkIf cfg.enable {
        home = {
            sessionVariables = {
                # Redirect npm global installs out of the read-only nix store
                NPM_CONFIG_PREFIX = "$HOME/.npm-global";
            };
            sessionPath = [ "$HOME/.npm-global/bin" ];
            packages = with pkgs; [
                uv
                nodejs_latest
                yarn
                openspec
            ];
        };
    };
}
