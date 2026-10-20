{ lib, python3Packages }:

python3Packages.buildPythonApplication {
    pname = "catprinter-share";
    version = "0.1.0";
    pyproject = true;
    src = lib.cleanSource ./gateway;

    build-system = [ python3Packages.setuptools ];
    dependencies = [ python3Packages.aiohttp ];
    pythonImportsCheck = [ "catprinter_share" ];
    checkPhase = ''
        runHook preCheck
        python -m unittest discover -s tests -v
        runHook postCheck
    '';
    postFixup = ''
        env -i "$out/bin/catprinter-share" --help >/dev/null
    '';

    meta = {
        description = "Expiring fixed-destination public Catprinter gateway";
        mainProgram = "catprinter-share";
        platforms = lib.platforms.linux;
    };
}
