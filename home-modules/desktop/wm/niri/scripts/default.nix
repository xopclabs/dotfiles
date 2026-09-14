{ pkgs, lib, config }:

let
    internalMon = config.metadata.hardware.monitors.internal;

    parsePosition = posStr: let
        xy = lib.splitString "x" posStr;
    in {
        x = lib.toInt (lib.elemAt xy 0);
        y = lib.toInt (lib.elemAt xy 1);
    };

    scratchPath = "${config.xdg.configHome}/niri/scratch.kdl";
    internalPosition = if internalMon != null then parsePosition internalMon.position else null;

    focusOutput = pkgs.writeShellScriptBin "niri-focus-output" ''
        export PATH=${lib.makeBinPath [ pkgs.niri pkgs.jq pkgs.coreutils ]}:$PATH
        ${builtins.readFile ./focus-output}
    '';

    autoPlaceOutputs = if internalMon != null then pkgs.writeShellScriptBin "niri-autoplace-outputs" ''
        export PATH=${lib.makeBinPath [ pkgs.niri pkgs.jq pkgs.coreutils ]}:$PATH
        ${builtins.replaceStrings
            [ "@INTERNAL_CONNECTORS@" "@INTERNAL_Y@" ]
            [ (builtins.toJSON internalMon.connectors) (toString internalPosition.y) ]
            (builtins.readFile ./autoplace-outputs)}
    '' else null;

    resetScratch = pkgs.writeShellScript "reset-niri-scratch" ''
        mkdir -p "$(dirname ${lib.escapeShellArg scratchPath})"
        cat > ${lib.escapeShellArg scratchPath} <<'EOF'
// Live niri overrides. Cleared on every home-manager switch.
EOF
    '';
in {
    inherit focusOutput autoPlaceOutputs resetScratch;

    packages = [
        focusOutput
    ] ++ lib.optional (autoPlaceOutputs != null) autoPlaceOutputs;
}
