{ timezone ? "\${__timezone}", baselineDays ? "\${baseline_days:raw}", outletBreakdown ? "\${outlet_breakdown:raw}" }:

let
    parameters = {
        inherit timezone;
        baselineDays = toString baselineDays;
        outletBreakdown = if builtins.isBool outletBreakdown then
            (if outletBreakdown then "true" else "false")
            else outletBreakdown;
    };
    bind = builtins.replaceStrings
        (map (name: "@${name}@") (builtins.attrNames parameters))
        (builtins.attrValues parameters);
    files = builtins.readDir ./.;
in
builtins.listToAttrs (builtins.concatMap (file:
    if builtins.match ".*\\.sql" file != null then [{
        name = builtins.substring 0 (builtins.stringLength file - 4) file;
        value = bind (builtins.readFile (./. + "/${file}"));
    }] else []
) (builtins.attrNames files))
