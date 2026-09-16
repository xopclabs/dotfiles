{ inputs, pkgs, lib, config, ... }:

let
    cfg = config.modules.desktop.wm.niri;
    sessionCfg = cfg.sessionRestore;

    # Use nirinit as a pinned source rather than its upstream flake package.
    # The upstream package currently fetches Cargo.lock crates through the crates.io
    # API download endpoint, which is rejected for some generic curl user agents.
    # buildRustPackage vendors through the static crate CDN and is reproducible via cargoHash.
    src = if inputs ? nirinit then inputs.nirinit else pkgs.fetchFromGitHub {
        owner = "amaanq";
        repo = "nirinit";
        rev = "0e43f61069f81bba1114475cae2e84aa0965a1a3";
        hash = "sha256-jpSYhiJNI5u/1CJ1RY+9BkSQtvishCfm5n+l9r7hdEk=";
    };
    package = pkgs.rustPlatform.buildRustPackage {
        pname = "nirinit";
        version = "0.2.2";
        inherit src;
        cargoHash = "sha256-11XYaPI4wUNmGI8xHQXtybHhL5jTOXrynwPnRHQoivA=";
        meta.mainProgram = "nirinit";
    };
    configFile = (pkgs.formats.toml { }).generate "nirinit-config.toml" sessionCfg.settings;
in {
    options.modules.desktop.wm.niri.sessionRestore = {
        enable = lib.mkEnableOption "nirinit session restore for niri";
        settings = lib.mkOption {
            type = (pkgs.formats.toml { }).type;
            default = {};
            description = "nirinit TOML settings.";
        };
    };

    config = lib.mkIf (cfg.enable && sessionCfg.enable) {
        home.packages = [ package ];

        systemd.user.services.nirinit = {
            Unit = {
                Description = "Nirinit niri session restore";
                After = [ "graphical-session.target" ];
                PartOf = [ "graphical-session.target" ];
                ConditionEnvironment = "NIRI_SOCKET";
            };
            Service = {
                ExecStart = "${lib.getExe package} --config ${configFile}";
                Restart = "always";
                RestartSec = 2;
            };
            Install.WantedBy = [ "graphical-session.target" ];
        };
    };
}
