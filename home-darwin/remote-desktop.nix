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
      displayName,
      protocol,
      host,
      port ? "",
      viewer ? "tigervnc",
      username ? config.home.username,
    }:
    let
      conn =
        if protocol == "vnc" then
          let
            # TigerVNC: /Applications/TigerVNC.app/Contents/MacOS/vncviewer
            # RealVNC Viewer: /Applications/VNC Viewer.app/Contents/MacOS/vncviewer
            isRealVnc = viewer == "realvnc";
            vncBin =
              if isRealVnc then
                "/Applications/VNC Viewer.app/Contents/MacOS/vncviewer"
              else
                "/Applications/TigerVNC.app/Contents/MacOS/vncviewer";
            # TigerVNC accepts `:display` (port=5900 -> :0) and `:port` (it
            # treats values >99 as a port). RealVNC requires `::port` for
            # explicit port — `:5900` would be parsed as display 5900 (invalid).
            vncTarget = "${host}${
              if port == "" then
                ""
              else if isRealVnc then
                "::${port}"
              else
                ":${port}"
            }";
            vncFlags = if isRealVnc then "" else "-FullScreen -FullscreenSystemKeys -RemoteResize";
            caskHint = if isRealVnc then "brew install --cask vnc-viewer" else "brew install --cask tigervnc";
          in
          ''
            VNC_BIN="${vncBin}"
            if [ ! -x "$VNC_BIN" ]; then
              echo "ERROR: VNC viewer no encontrado en $VNC_BIN" >&2
              echo "       Instalar con: ${caskHint}" >&2
              exit 1
            fi
            exec "$VNC_BIN" ${vncFlags} "${vncTarget}"
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
        <string>${displayName}</string>
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
    # VNC hosts: dual launchers (TigerVNC + RealVNC Viewer) per host for
    # side-by-side comparison. wayvnc on t14 / mact2 supports both clients
    # via the standard VNC RFB protocol.
    {
      name = "t14-tigervnc";
      displayName = "t14 (TigerVNC)";
      protocol = "vnc";
      viewer = "tigervnc";
      host = "172.16.0.109";
      port = "5900";
    }
    {
      name = "t14-realvnc";
      displayName = "t14 (RealVNC)";
      protocol = "vnc";
      viewer = "realvnc";
      host = "172.16.0.109";
      port = "5900";
    }
    {
      name = "mact2-tigervnc";
      displayName = "mact2 (TigerVNC)";
      protocol = "vnc";
      viewer = "tigervnc";
      host = "mact2.local";
    }
    {
      name = "mact2-realvnc";
      displayName = "mact2 (RealVNC)";
      protocol = "vnc";
      viewer = "realvnc";
      host = "mact2.local";
    }
    # RDP hosts: single launcher each
    {
      name = "oneplus5";
      displayName = "oneplus5 (RDP)";
      protocol = "rdp";
      host = "172.16.0.12";
    }
    {
      name = "rog";
      displayName = "rog (RDP)";
      protocol = "rdp";
      host = "172.16.0.5";
    }
    {
      name = "thinkcentre";
      displayName = "thinkcentre (RDP)";
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
