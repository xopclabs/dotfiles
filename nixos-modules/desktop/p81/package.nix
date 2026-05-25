{ stdenv, dpkg }:

stdenv.mkDerivation rec {
    pname = "perimeter81";
    version = "10.1.0.53";

    src = builtins.fetchurl {
        url = "https://static.perimeter81.com/agents/linux/Perimeter81_${version}.deb";
        sha256 = "sha256:041j3hkzm79gb47i3vhdaf6rmdydp38vhhmgr0dv7zzjw3mzhayv";
    };

    nativeBuildInputs = [ dpkg ];

    unpackPhase = ''
        runHook preUnpack
        dpkg-deb -x $src .
        runHook postUnpack
    '';

    installPhase = ''
        runHook preInstall

        mkdir -p "$out/bin"
        cp -R "opt" "$out"
        cp -R "usr/share" "$out/share"
        chmod -R g-w "$out"
        mkdir -p "$out/share/applications"

        runHook postInstall
    '';
}
