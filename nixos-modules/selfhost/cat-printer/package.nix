{ lib, python3Packages, dejavu_fonts, noto-fonts-monochrome-emoji }:

python3Packages.buildPythonApplication {
    pname = "catprinter-service";
    version = "0.1.0";
    pyproject = true;
    src = lib.cleanSource ./service;

    build-system = [ python3Packages.setuptools ];
    dependencies = with python3Packages; [
        aiohttp bleak pillow markdown-it-py fonttools regex
    ];
    CATPRINTER_FONT_DIR = "${dejavu_fonts}/share/fonts/truetype";
    CATPRINTER_EMOJI_FONT = "${noto-fonts-monochrome-emoji}/share/fonts/noto/NotoEmoji.ttf";
    makeWrapperArgs = [
        "--set CATPRINTER_FONT_DIR ${dejavu_fonts}/share/fonts/truetype"
        "--set CATPRINTER_EMOJI_FONT ${noto-fonts-monochrome-emoji}/share/fonts/noto/NotoEmoji.ttf"
    ];
    pythonImportsCheck = [ "catprinter.server" ];

    meta = {
        description = "Private MX10 printer API with serialized BLE ownership and keepalive";
        mainProgram = "catprinter-service";
        platforms = lib.platforms.linux;
    };
}
