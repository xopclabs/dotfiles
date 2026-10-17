{ lib, python3Packages }:

python3Packages.buildPythonApplication {
    pname = "catprint";
    version = "0.1.0";
    pyproject = true;
    src = lib.cleanSourceWith {
        src = ./.;
        filter = path: type:
            let name = baseNameOf path;
            in !(builtins.elem name [ "__pycache__" ".ruff_cache" ".pytest_cache" ])
                && !(lib.hasSuffix ".nix" name);
    };
    build-system = [ python3Packages.setuptools ];
    pythonImportsCheck = [ "catprint" ];
    meta = {
        description = "Enqueue text and image prints through the cat printer API";
        mainProgram = "catprint";
        platforms = lib.platforms.unix;
    };
}
