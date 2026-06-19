# Remote desktop client launchers for Darwin (macOS).
#
# Creates .app bundles that appear in Spotlight.
# VNC connections use TigerVNC (Homebrew cask) which supports VeNCrypt/TLS
# required by wayvnc's PAM auth. macOS native Screen Sharing.app does not.
# RDP connections use sdl-freerdp (FreeRDP SDL3/Metal client, no X11 needed).
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
          ''
            VNC_BIN="/Applications/TigerVNC.app/Contents/MacOS/vncviewer"
            if [ ! -x "$VNC_BIN" ]; then
              echo "ERROR: TigerVNC no encontrado en $VNC_BIN" >&2
              echo "       Instalar con: brew install --cask tigervnc" >&2
              exit 1
            fi
            exec "$VNC_BIN" -FullScreen -FullscreenSystemKeys -RemoteResize "${host}${
              if port != "" then ":${port}" else ""
            }"
          ''
        else
          "${pkgs.freerdp}/bin/sdl-freerdp /v:${host} /u:${username} /p: /cert:ignore /sound:sys:mac /clipboard /w:1920 /h:1080 /smart-sizing /gfx:progressive /bpp:32 /kbd:layout:0x0000040A,lang:0x040A";
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
