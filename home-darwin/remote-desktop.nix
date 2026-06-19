# Remote desktop client launchers for Darwin (macOS).
#
# Creates .app bundles that appear in Spotlight.
# VNC connections use the native Screen Sharing.app (via `open vnc://`).
# RDP connections use xfreerdp from nixpkgs.
{ pkgs, ... }:

let
  # Helper to create a .app bundle for Spotlight
  mkRemoteApp =
    {
      name,
      protocol,
      host,
      port ? "",
    }:
    let
      # VNC: use macOS native Screen Sharing.app
      # RDP: use xfreerdp from nixpkgs
      conn =
        if protocol == "vnc" then
          "open vnc://${host}${if port != "" then ":${port}" else ""}"
        else
          "${pkgs.freerdp}/bin/xfreerdp /v:${host} /u:glats /cert-ignore /sec:nla +clipboard +home-drive";
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
      cat > $out/remote-${name}.app/Contents/MacOS/launcher <<EOF
      #!/bin/sh
      exec ${conn}
      EOF
      chmod +x $out/remote-${name}.app/Contents/MacOS/launcher
    '';
in
{
  home.file = {
    # === VNC connections (native Screen Sharing.app) ===
    "Applications/remote-t14.app" = {
      source =
        "$${
        mkRemoteApp {
          name = " t14 ";
          protocol = " vnc
          ";
          host = "
          172.16
          .0
          .109
          ";
          port = "
          5900
          ";
        }
      }/remote-t14.app";
      recursive = true;
    };
    "Applications/remote-mact2.app" = {
      source =
        "$${
        mkRemoteApp {
          name = " mact2 ";
          protocol = " vnc
          ";
          host = "
          mact2.local
          ";
        }
      }/remote-mact2.app";
      recursive = true;
    };

    # === RDP connections (xfreerdp) ===
    "Applications/remote-oneplus5.app" = {
      source =
        "$${
        mkRemoteApp {
          name = " oneplus5 ";
          protocol = " rdp
          ";
          host = "
          172.16
          .0
          .12
          ";
        }
      }/remote-oneplus5.app";
      recursive = true;
    };
    "Applications/remote-rog.app" = {
      source =
        "$${
        mkRemoteApp {
          name = " rog ";
          protocol = " rdp
          ";
          host = "
          172.16
          .0
          .5
          ";
        }
      }/remote-rog.app";
      recursive = true;
    };
    "Applications/remote-thinkcentre.app" = {
      source =
        "$${
        mkRemoteApp {
          name = " thinkcentre ";
          protocol = " rdp
          ";
          host = "
          172.16
          .0
          .11
          ";
        }
      }/remote-thinkcentre.app";
      recursive = true;
    };
  };
}
