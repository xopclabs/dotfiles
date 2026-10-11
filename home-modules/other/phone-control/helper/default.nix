# Build/sign: nix run --impure --expr 'import ./home-modules/other/phone-control/helper {}'
{ pkgs ? import (builtins.getFlake (toString ../../../..)).inputs.nixpkgs {
    system = builtins.currentSystem;
    config = { allowUnfree = true; android_sdk.accept_license = true; };
} }:

let
    android = pkgs.androidenv.composeAndroidPackages {
        platformVersions = [ "36" ];
        buildToolsVersions = [ "36.0.0" ];
        includeCmake = false;
    };
    sdk = "${android.androidsdk}/libexec/android-sdk";
    tools = "${sdk}/build-tools/36.0.0";
    glyph = ''
        <path android:fillColor="#FFFFFFFF" android:fillType="evenOdd"
            android:pathData="M7,2H13A2,2 0,0 1,15 4V20A2,2 0,0 1,13 22H7A2,2 0,0 1,5 20V4A2,2 0,0 1,7 2Z M7,4V18H13V4Z M10,19.5A0.75,0.75 0,1 0,10 21A0.75,0.75 0,1 0,10 19.5Z" />
        <path android:fillColor="#00000000" android:strokeColor="#FFFFFFFF"
            android:strokeWidth="1.6" android:strokeLineCap="round"
            android:pathData="M16,5Q20,1 24,5 M17.7,7Q20,4.7 22.3,7 M20,9L20,9.1" />
    '';
    theme = night: ''
        <resources>
            <color name="background">${if night then "#242933" else "#F2F5F7"}</color>
            <color name="surface">${if night then "#2E3440" else "#FFFFFF"}</color>
            <color name="ink">${if night then "#ECEFF4" else "#253041"}</color>
            <color name="muted">${if night then "#B8C2D1" else "#5B6776"}</color>
            <color name="accent">${if night then "#88C0D0" else "#286777"}</color>
            <color name="accent_surface">${if night then "#394957" else "#E0EEF1"}</color>
            <color name="border">${if night then "#465261" else "#C9D6DC"}</color>
            <color name="icon_background">#2E3440</color>
            <style name="HelperTheme" parent="android:style/Theme.Material.${if night then "" else "Light."}NoActionBar">
                <item name="android:fontFamily">sans</item>
                <item name="android:colorAccent">@color/accent</item>
                <item name="android:windowBackground">@color/background</item>
                <item name="android:windowLightStatusBar">${if night then "false" else "true"}</item>
                <item name="android:windowLightNavigationBar">${if night then "false" else "true"}</item>
                <item name="android:windowSplashScreenBackground">@color/background</item>
            </style>
        </resources>
    '';
    resources = {
        "values/theme.xml" = theme false;
        "values-night/theme.xml" = theme true;
        "drawable/ic_phone.xml" = ''
            <vector xmlns:android="http://schemas.android.com/apk/res/android"
                android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24">
                ${glyph}
            </vector>
        '';
        "drawable/ic_launcher_foreground.xml" = ''
            <vector xmlns:android="http://schemas.android.com/apk/res/android"
                android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
                <group android:scaleX="2.5" android:scaleY="2.5" android:translateX="24" android:translateY="24">
                    ${glyph}
                </group>
            </vector>
        '';
        "mipmap-anydpi-v26/ic_launcher.xml" = ''
            <adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
                <background android:drawable="@color/icon_background" />
                <foreground android:drawable="@drawable/ic_launcher_foreground" />
            </adaptive-icon>
        '';
        "mipmap-anydpi-v33/ic_launcher.xml" = ''
            <adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
                <background android:drawable="@color/icon_background" />
                <foreground android:drawable="@drawable/ic_launcher_foreground" />
                <monochrome android:drawable="@drawable/ic_launcher_foreground" />
            </adaptive-icon>
        '';
    };
    manifest = ''
        <manifest xmlns:android="http://schemas.android.com/apk/res/android"
            package="dev.phonecontrol.debugginghelper" android:versionCode="10" android:versionName="0.10">
            <uses-sdk android:minSdkVersion="30" android:targetSdkVersion="36" />
            ${pkgs.lib.concatMapStrings (permission: ''
                <uses-permission android:name="android.permission.${permission}" />
            '') [
                "INTERNET" "WRITE_SECURE_SETTINGS" "ACCESS_WIFI_STATE" "ACCESS_NETWORK_STATE"
                "ACCESS_FINE_LOCATION" "ACCESS_COARSE_LOCATION" "ACCESS_BACKGROUND_LOCATION"
                "POST_NOTIFICATIONS" "RECEIVE_BOOT_COMPLETED" "FOREGROUND_SERVICE"
                "FOREGROUND_SERVICE_SPECIAL_USE"
            ]}
            <queries>
                <package android:name="com.android.dialer" />
                <package android:name="com.android.messaging" />
                <package android:name="io.heckel.ntfy" />
                <intent>
                    <action android:name="android.intent.action.MAIN" />
                    <category android:name="android.intent.category.LAUNCHER" />
                </intent>
            </queries>
            <application android:label="Phone Control" android:allowBackup="false"
                android:icon="@mipmap/ic_launcher" android:roundIcon="@mipmap/ic_launcher"
                android:supportsRtl="true" android:theme="@style/HelperTheme">
                <activity android:name=".MainActivity" android:exported="true">
                    <intent-filter>
                        <action android:name="android.intent.action.MAIN" />
                        <category android:name="android.intent.category.LAUNCHER" />
                    </intent-filter>
                </activity>
                <provider android:name=".PairingProvider"
                    android:authorities="dev.phonecontrol.debugginghelper.pairing"
                    android:exported="true" android:grantUriPermissions="false" />
                <service android:name=".RelayListener" android:exported="true"
                    android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE">
                    <intent-filter>
                        <action android:name="android.service.notification.NotificationListenerService" />
                    </intent-filter>
                </service>
                <service android:name=".RecoveryService" android:exported="false"
                    android:foregroundServiceType="specialUse">
                    <property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
                        android:value="Restore paired encrypted debugging on trusted Wi-Fi" />
                </service>
                <receiver android:name=".BootReceiver" android:exported="false">
                    <intent-filter>
                        <action android:name="android.intent.action.BOOT_COMPLETED" />
                        <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                    </intent-filter>
                </receiver>
            </application>
        </manifest>
    '';
    apk = pkgs.runCommand "wireless-debugging-helper-unsigned.apk" {
        nativeBuildInputs = [ pkgs.jdk17 pkgs.kotlin pkgs.zip ];
        inherit manifest;
        passAsFile = [ "manifest" ];
    } ''
        export HOME="$TMPDIR" JAVA_HOME=${pkgs.jdk17}
        mkdir dex
        cp "$manifestPath" AndroidManifest.xml
        ${pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (path: xml: ''
            mkdir -p res/${builtins.dirOf path}
            cp ${pkgs.writeText (builtins.baseNameOf path) xml} res/${path}
        '') resources)}
        ${tools}/aapt package -f -M AndroidManifest.xml -S res \
            -I ${sdk}/platforms/android-36/android.jar -F resources.apk
        kotlinc ${./Helper.kt} -jvm-target 1.8 -Xlambdas=class -Xsam-conversions=class \
            -classpath ${sdk}/platforms/android-36/android.jar -d helper.jar
        cat > rules.pro <<'EOF'
        -keep class dev.phonecontrol.debugginghelper.MainActivity { public protected *; }
        -keep class dev.phonecontrol.debugginghelper.PairingProvider { public protected *; }
        -keep class dev.phonecontrol.debugginghelper.RelayListener { public protected *; }
        -keep class dev.phonecontrol.debugginghelper.RecoveryService { public protected *; }
        -keep class dev.phonecontrol.debugginghelper.BootReceiver { public protected *; }
        -dontwarn org.jetbrains.annotations.**
        EOF
        # Shrink the Kotlin standard library rather than shipping it wholesale.
        java -cp ${tools}/lib/d8.jar com.android.tools.r8.R8 --release --min-api 30 \
            --lib ${sdk}/platforms/android-36/android.jar --pg-conf rules.pro --output dex \
            helper.jar ${pkgs.kotlin}/lib/kotlin-stdlib.jar
        cp resources.apk unsigned.apk
        (cd dex; zip -q ../unsigned.apk classes.dex)
        ${tools}/zipalign -p -f 4 unsigned.apk "$out"
    '';
in
(pkgs.writeShellApplication {
    name = "build-phone-helper";
    runtimeInputs = [ pkgs.jdk17 ];
    text = ''
        umask 077
        export JAVA_HOME=${pkgs.jdk17}
        state_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/phone-control-helper"
        mkdir -p "$state_dir"
        key="$state_dir/test-signing.p12"
        if [[ ! -e "$key" ]]; then
            keytool -genkeypair -keystore "$key" -storetype PKCS12 \
                -storepass android -keypass android -alias helper \
                -keyalg RSA -keysize 2048 -validity 3650 -dname 'CN=Wireless Debugging Test'
        fi
        apk="$state_dir/wireless-debugging-test.apk"
        ${tools}/apksigner sign --ks "$key" --ks-key-alias helper \
            --ks-pass pass:android --key-pass pass:android --out "$apk" ${apk}
        ${tools}/apksigner verify "$apk"
        printf '%s\n' "$apk"
    '';
}).overrideAttrs (_: { passthru = { inherit apk; }; })
