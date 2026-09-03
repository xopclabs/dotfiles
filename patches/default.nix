{ lib }:

let
    patchesIn = dir:
        lib.pipe (builtins.readDir dir) [
            (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".patch" name))
            builtins.attrNames
            lib.naturalSort
            (map (name: dir + "/${name}"))
        ];
    dirs = lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./.);
in
    lib.mapAttrs (name: _: patchesIn (./. + "/${name}")) dirs
