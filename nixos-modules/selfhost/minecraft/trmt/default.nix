{
    lib,
    stdenv,
    fetchFromGitHub,
    gradle_9,
    jdk25,
    runCommand,
    writeText,
}:

let
    gradle = gradle_9;
in
stdenv.mkDerivation (finalAttrs: {
    pname = "trmt";
    version = "0.5.1-26.2-fabric";
    # Minecraft only loads *.jar from the mods directory; linkFarmFromDrvs uses drv.name.
    name = "${finalAttrs.pname}-${finalAttrs.version}.jar";

    src = fetchFromGitHub {
        owner = "Vadyanik";
        repo = "trmt";
        # milkucha/trmt#61 (26.2 Fabric port), unreleased on Modrinth.
        rev = "3682918d67970a67f348ba6d21b6a9ac12d87472";
        hash = "sha256-bgHsRvXi0bCYgaWuQnU3yoGZ7FM6kS0aeR8SJWNZDNE=";
    };

    nativeBuildInputs = [ gradle jdk25 ];

    # Loom requests Mojang's mutable version list even for a pinned Minecraft release.
    # Supply a stable, minimal list for 26.2 instead of hashing the changing endpoint.
    # If regenerating deps.json, remove its version_manifest_v2 entry again.
    mitmCache = let
        fetched = gradle.fetchDeps {
            pkg = finalAttrs.finalPackage;
            data = ./deps.json;
        };
        manifest = writeText "version_manifest_v2.json" (builtins.toJSON {
            latest = { release = "26.2"; snapshot = "26.2"; };
            versions = [{
                id = "26.2";
                type = "release";
                url = "https://piston-meta.mojang.com/v1/packages/bc42e43dfe43d65a2f6c2c1dbb322c75134e51fe/26.2.json";
                time = "2026-09-11T06:44:16+00:00";
                releaseTime = "2026-06-16T12:03:33+00:00";
                sha1 = "bc42e43dfe43d65a2f6c2c1dbb322c75134e51fe";
                complianceLevel = 1;
            }];
        });
    in runCommand "trmt-deps-pinned-manifest" {} ''
        cp -r ${fetched}/. "$out/"
        find "$out" -type d -exec chmod u+w {} +
        mkdir -p "$out/https/piston-meta.mojang.com/mc/game"
        ln -s ${manifest} "$out/https/piston-meta.mojang.com/mc/game/version_manifest_v2.json"
    '';

    # Loom replaces the jar task; nixpkgs' reproducible-archive init script breaks that.
    gradleInitScript = writeText "empty-init-script.gradle" "";

    gradleFlags = [
        "-Dfile.encoding=utf-8"
        "-Dorg.gradle.java.home=${jdk25}"
    ];

    # Minecraft 26.1+ is unobfuscated; Loom 1.17's jar task is the production artifact.
    # Running jar for the lockfile also captures Loom's Minecraft/Mojang downloads.
    gradleBuildTask = "jar";
    gradleUpdateTask = "jar";
    doCheck = false;

    installPhase = ''
        runHook preInstall
        cp build/libs/trmt-${finalAttrs.version}.jar "$out"
        runHook postInstall
    '';

    meta = {
        description = "The Roads More Travelled: terrain erosion from walking";
        homepage = "https://github.com/milkucha/trmt";
        license = lib.licenses.cc-by-nc-40;
        sourceProvenance = with lib.sourceTypes; [
            fromSource
            binaryBytecode
        ];
    };
})
