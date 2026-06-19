# Remote desktop client launchers for Darwin (macOS).
#
# Creates .app bundles that appear in Spotlight.
# VNC connections use the native Screen Sharing.app (via `open vnc://`).
# RDP connections use Microsoft Remote Desktop (via Homebrew cask).
{ pkgs, ... }:

let
  mkRemoteApp =
    {
      name,
      protocol,
      host,
      port ? "",
      username ? "glats",
    }:
    let
      conn =
        if protocol == "vnc" then
          "open vnc://${host}${if port != "" then ":${port}" else ""}"
        else
          ''
            TMP_RDP="$TMPDIR/remote-${name}.rdp"
            cat > "$TMP_RDP" <<'RDP'
            full address:s:${host}
            username:s:${username}
            screen mode id:i:1
            use multimon:i:0
            session bpp:i:32
            compression:i:1
            keyboardhook:i:2
            audiocapturemode:i:0
            videoplaybackmode:i:1
            connection type:i:2
            networkautodetect:i:1
            bandwidthautodetect:i:1
            enableworkspacereconnect:i:0
            disable wallpaper:i:0
            allow font smoothing:i:1
            allow desktop composition:i:1
            disable full window drag:i:0
            disable menu anims:i:0
            disable themes:i:0
            disable cursor setting:i:0
            bitmapcachepersistenable:i:1
            audiomode:i:0
            redirectprinters:i:0
            redirectcomports:i:0
            redirectsmartcards:i:0
            redirectclipboard:i:1
            redirectposdevices:i:0
            autoreconnection enabled:i:1
            prompt for credentials:i:0
            negotiate security layer:i:1
            remoteapplicationmode:i:0
            alternate shell:s:
            shell working directory:s:
            gatewayhostname:s:
            gatewayusagemethod:i:4
            gatewaycredentialssource:i:4
            gatewayprofileusagemethod:i:0
            promptcredentialonce:i:1
            use redirection server name:i:0
            RDP
            open -a "Microsoft Remote Desktop" "$TMP_RDP"
          '';
    in
    pkgs.runCommand "remote-${name}.app" { } ''
      mkdir -p $out/remote-${name}.app/Contents/MacOS
      cat > $out/remote-${name}.app/Contents/Info.plist <<'EOF'
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleName</key>
        <string>remote-${name}</string>
        <key>CFBundleDisplayName</key>
        <string>${name} (${protocol})</string>
        <key>CFBundleIdentifier</key>
        <string>com.glats.remote.${name}</string>
        <key>CFBundleVersion</key>
        <string>1.0</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>CFBundleExecutable</key>
        <string>launcher</string>
      </dict>
      </plist>
      EOF
      cat > $out/remote-${name}.app/Contents/MacOS/launcher <<'LAUNCHER'
      #!/bin/sh
      ${conn}
      LAUNCHER
      chmod +x $out/remote-${name}.app/Contents/MacOS/launcher
    '';
in
{
  home.file = {
    "Applications/remote-t14.app" = {
      source = "${
        mkRemoteApp {
          name = "t14";
          protocol = "vnc";
          host = "172.16.0.109";
          port = "5900";
        }
      }/remote-t14.app";
      recursive = true;
    };
    "Applications/remote-mact2.app" = {
      source = "${
        mkRemoteApp {
          name = "mact2";
          protocol = "vnc";
          host = "mact2.local";
        }
      }/remote-mact2.app";
      recursive = true;
    };
    "Applications/remote-oneplus5.app" = {
      source = "${
        mkRemoteApp {
          name = "oneplus5";
          protocol = "rdp";
          host = "172.16.0.12";
        }
      }/remote-oneplus5.app";
      recursive = true;
    };
    "Applications/remote-rog.app" = {
      source = "${
        mkRemoteApp {
          name = "rog";
          protocol = "rdp";
          host = "172.16.0.5";
        }
      }/remote-rog.app";
      recursive = true;
    };
    "Applications/remote-thinkcentre.app" = {
      source = "${
        mkRemoteApp {
          name = "thinkcentre";
          protocol = "rdp";
          host = "172.16.0.11";
        }
      }/remote-thinkcentre.app";
      recursive = true;
    };
  };
}
