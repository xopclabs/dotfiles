{ pkgs, ... }:

let
    codexbar = pkgs.stdenv.mkDerivation rec {
        pname = "codexbar";
        version = "0.56.8";

        src = pkgs.fetchurl {
            url = "https://github.com/steipete/CodexBar/releases/download/v${version}/CodexBarCLI-v${version}-linux-musl-x86_64.tar.gz";
            sha256 = "fef21962d7b6b6b520455c929a211a162d05aaa2d4f63ecf54aacfbce0a83887";
        };

        sourceRoot = ".";

        nativeBuildInputs = [ pkgs.python3 ];

        # The musl static Swift binary hardcodes "/usr/bin/which", which does not exist on NixOS.
        # Patch the hardcoded path to "/tmp/which" and wrapper generates the fallback script if missing.
        patchPhase = ''
            python3 -c '
            with open("codexbar", "rb") as f:
                data = bytearray(f.read())
            pattern = bytes([0x49, 0xbe]) + b"/usr/bin" + bytes([0x48, 0xbb]) + b"/which\x00\xee"
            pos = data.find(pattern)
            assert pos != -1, "pattern not found"
            replacement = bytes([0x49, 0xbe]) + b"/tmp/whi" + bytes([0x48, 0xbb, 0x63, 0x68, 0x00, 0x00, 0x00, 0x00, 0x00, 0xea])
            data[pos:pos+len(replacement)] = replacement
            with open("codexbar", "wb") as f:
                f.write(data)
            '
        '';

        installPhase = ''
            mkdir -p $out/libexec $out/bin
            cp codexbar $out/libexec/codexbar
            chmod +x $out/libexec/codexbar

            cat << 'EOF' > $out/bin/codexbar
            #!/bin/sh
            if [ ! -x /tmp/which ]; then
                cat << 'WEOF' > /tmp/which
            #!/bin/sh
            for p in $(echo "$PATH" | tr ':' ' '); do
                if [ -x "$p/$1" ] && [ ! -d "$p/$1" ]; then
                    echo "$p/$1"
                    exit 0
                fi
            done
            exit 1
            WEOF
                chmod +x /tmp/which 2>/dev/null || true
            fi
            EOF

            echo "exec $out/libexec/codexbar \"\$@\"" >> $out/bin/codexbar
            chmod +x $out/bin/codexbar
        '';
    };
in {
    inherit codexbar;
}
