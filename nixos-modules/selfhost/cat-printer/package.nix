{ lib, fetchurl, python3Packages, dejavu_fonts, noto-fonts-monochrome-emoji }:

python3Packages.buildPythonApplication {
    pname = "catprinter-service";
    version = "0.1.0";
    pyproject = true;
    src = lib.cleanSource ./service;

    # CSP-compatible decoder: no CDN requests or unsafe-eval at runtime.
    postPatch = let
        heicTo = fetchurl {
            url = "https://registry.npmjs.org/heic-to/-/heic-to-1.6.6.tgz";
            hash = "sha256-bcRwPmIEjDcuvvljLOhhPVNZjOrM8NiR++ClM5Cc8aU=";
        };
    in ''
        tar -xzf ${heicTo} package/dist/csp/heic-to.js package/LICENSE
        cp package/dist/csp/heic-to.js catprinter/static/heic-to.js
        cp package/LICENSE catprinter/static/heic-to.LICENSE
        rm -r package
    '';

    build-system = [ python3Packages.setuptools ];
    dependencies = with python3Packages; [
        aiohttp bleak pillow markdown-it-py fonttools regex pylibdmtx
        packaging # pylibdmtx.wrapper imports this but omits it from its metadata.
    ];
    CATPRINTER_FONT_DIR = "${dejavu_fonts}/share/fonts/truetype";
    CATPRINTER_EMOJI_FONT = "${noto-fonts-monochrome-emoji}/share/fonts/noto/NotoEmoji.ttf";
    makeWrapperArgs = [
        "--set CATPRINTER_FONT_DIR ${dejavu_fonts}/share/fonts/truetype"
        "--set CATPRINTER_EMOJI_FONT ${noto-fonts-monochrome-emoji}/share/fonts/noto/NotoEmoji.ttf"
    ];
    postInstall = ''
        for asset in index.html style.css app.js image-decode.js heic-to.js heic-to.LICENSE; do
            test -s "$out/${python3Packages.python.sitePackages}/catprinter/static/$asset"
        done
    '';
    postFixup = ''
        # Test the wrapped runtime without build-time Python dependencies.
        env -i "$out/bin/catprinter-service" --help >/dev/null
    '';
    checkPhase = ''
        runHook preCheck
        python -m unittest discover -s tests -v
        runHook postCheck
    '';
    pythonImportsCheck = [ "catprinter.server" ];

    meta = {
        description = "Private MX10 printer API with serialized BLE ownership and keepalive";
        mainProgram = "catprinter-service";
        platforms = lib.platforms.linux;
    };
}
