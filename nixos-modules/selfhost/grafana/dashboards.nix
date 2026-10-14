let
    queries = import ./queries/queries.nix {};
    resolve = value:
        if builtins.isAttrs value then builtins.mapAttrs (_: resolve) value
        else if builtins.isList value then map resolve value
        else if builtins.isString value then
            let reference = builtins.match "@query:([a-z0-9-]+)@" value;
            in if reference == null then value else queries.${builtins.head reference}
        else value;
in
builtins.mapAttrs (file: _: resolve (builtins.fromJSON (builtins.readFile (./dashboards + "/${file}"))))
    (builtins.readDir ./dashboards)
