# Remote desktop client launchers for Darwin (macOS).
#
# Creates .app bundles that appear in Spotlight. Real bundles (not symlinks)
# are deployed to ~/Applications and ad-hoc signed, so macOS Local Network
# Privacy prompts resolve cleanly.
#
# VNC connections: dual launchers (TigerVNC + RealVNC Viewer) per host for
# side-by-side comparison. Both are Homebrew casks (`tigervnc`, `vnc-viewer`).
# TigerVNC supports VeNCrypt/TLS required by wayvnc's PAM auth; macOS
# native Screen Sharing.app does not.
# RDP connections: sdl-freerdp (FreeRDP SDL3/Metal client, no X11 needed).
{
  config,
  pkgs,
  lib,
  ...
}:

let
  mkRemoteApp =
    {
      name,
      protocol,
      host,
      port ? "",
      username ? config.home.username,
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
          ''
            export HOME="''${HOME:-/Users/${username}}"
            cd "$HOME"
            exec ${pkgs.freerdp}/bin/sdl-freerdp /v:${host} /u:${username} /p: /cert:ignore /sound:sys:mac /clipboard /w:1920 /h:1080 /smart-sizing /gfx:progressive /bpp:32 /kbd:layout:0x0000040A,lang:0x040A >>"$HOME/Library/Logs/remote-${name}.log" 2>&1
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
        <key>LSUIElement</key>
        <true/>
        <key>NSLocalNetworkUsageDescription</key>
        <string>Remote desktop needs local network access to connect to your machines.</string>
      </dict>
      </plist>
      EOF
      cat > $out/remote-${name}.app/Contents/MacOS/launcher <<'LAUNCHER'
      #!/bin/sh
      ${conn}
      LAUNCHER
      chmod +x $out/remote-${name}.app/Contents/MacOS/launcher
    '';

  apps = [
    {
      name = "t14";
      protocol = "vnc";
      host = "172.16.0.109";
      port = "5900";
    }
    {
      name = "mact2";
      protocol = "vnc";
      host = "mact2.local";
    }
    {
      name = "oneplus5";
      protocol = "rdp";
      host = "172.16.0.12";
    }
    {
      name = "rog";
      protocol = "rdp";
      host = "172.16.0.5";
    }
    {
      name = "thinkcentre";
      protocol = "rdp";
      host = "172.16.0.11";
    }
  ];

  appSources = lib.listToAttrs (
    map (app: {
      name = app.name;
      value = mkRemoteApp app;
    }) apps
  );

in
{
  # Use home.activation to copy real app bundles (not symlinks) and sign them.
  # Symlinks don't work well with macOS Local Network Privacy and Spotlight.
  home.activation.deployRemoteDesktopApps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    appsDir="$HOME/Applications"
    mkdir -p "$appsDir"

    ${lib.concatMapStrings (app: ''
      src="${appSources.${app.name}}/remote-${app.name}.app"
      dst="$appsDir/remote-${app.name}.app"

      # Remove old symlink or bundle if present
      if [ -L "$dst" ] || [ -e "$dst" ]; then
        rm -rf "$dst"
      fi

      # Copy real bundle (not symlink)
      cp -R "$src" "$dst"

      # Remove quarantine bits
      xattr -cr "$dst" 2>/dev/null || true

      # Ad-hoc sign the bundle so macOS can identify it for Local Network Privacy
      /usr/bin/codesign --force --sign - "$dst" 2>/dev/null || true
    '') apps}

    # Re-index for Spotlight
    mdimport "$appsDir" 2>/dev/null || true
  '';
}
