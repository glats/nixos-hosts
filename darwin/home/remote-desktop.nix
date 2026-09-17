# Remote desktop client launchers for Darwin (macOS).
#
# Not shared with linux/home/remote-desktop.nix: macOS requires native Mach-O
# app bundles and uses different host metadata (IPs, viewer types).
#
# Creates .app bundles that appear in Spotlight. Uses native C launchers
# instead of shell scripts to satisfy macOS Sequoia Launch Constraints.
{
  config,
  pkgs,
  lib,
  ...
}:

let
  # Generate C source for native Mach-O launcher
  mkLauncherC =
    {
      id,
      protocol,
      host,
      port ? "",
      viewer ? "tigervnc",
      username ? config.home.username,
    }:
    let
      vncHost = "${host}${if port != "" then ":${port}" else ""}";
      execCommand =
        if protocol == "vnc" && viewer == "realvnc" then
          ''
            const char *vncbin = "/Applications/VNC Viewer.app/Contents/MacOS/vncviewer";
            const char *args[] = {
              vncbin,
              "ColorLevel=full",
              "${vncHost}",
              NULL
            };
            execv(vncbin, (char *const *)args);
          ''
        else if protocol == "vnc" then
          ''
            const char *vncbin = "/Applications/TigerVNC.app/Contents/MacOS/vncviewer";
            const char *args[] = {
              vncbin,
              "-FullScreen",
              "-FullscreenSystemKeys",
              "-RemoteResize",
              "${vncHost}",
              NULL
            };
            execv(vncbin, (char *const *)args);
          ''
        else
          ''
            const char *rdpbin = "${pkgs.freerdp}/bin/sdl-freerdp";
            const char *args[] = {
              rdpbin,
              "/v:${host}",
              "/u:${username}",
              "/p:",
              "/cert:ignore",
              "/workarea",
              "/w:1680",
              "/h:1050",
              "/smart-sizing",
              "/network:auto",
              "/gfx:progressive",
              "/bpp:32",
              "/sound:sys:mac",
              "/clipboard",
              "/rfx-mode:video",
              "-wallpaper",
              "-themes",
              "-fonts",
              "/kbd:layout:0x0000080A,lang:0x040A",
              NULL
            };
            execv(rdpbin, (char *const *)args);
          '';
    in
    ''
      #include <stdio.h>
      #include <stdlib.h>
      #include <unistd.h>
      #include <pwd.h>
      #include <string.h>

      int main(int argc, char *argv[]) {
          struct passwd *pw = getpwuid(getuid());
          if (pw) {
              setenv("HOME", pw->pw_dir, 1);
              chdir(pw->pw_dir);
          }

          if (pw) {
              char logpath[1024];
               snprintf(logpath, sizeof(logpath), "%s/Library/Logs/remote-${id}.log", pw->pw_dir);
              FILE *log = fopen(logpath, "a");
              if (log) {
                  dup2(fileno(log), STDOUT_FILENO);
                  dup2(fileno(log), STDERR_FILENO);
                  fclose(log);
              }
          }

          ${execCommand}

          perror("execv failed");
          return 1;
      }
    '';

  mkRemoteApp =
    {
      id,
      bundleName,
      protocol,
      host,
      port ? "",
      viewer ? "tigervnc",
      username ? config.home.username,
    }:
    let
      launcherC = mkLauncherC {
        inherit
          id
          protocol
          host
          port
          viewer
          username
          ;
      };
    in
    pkgs.stdenv.mkDerivation {
      name = "remote-${id}.app";
      phases = [
        "buildPhase"
        "installPhase"
      ];
      buildPhase = ''
        cat > launcher.c <<'CSOURCE'
        ${launcherC}
        CSOURCE
        $CC -O2 -o launcher launcher.c
      '';
      installPhase = ''
        mkdir -p "$out/${bundleName}.app/Contents/MacOS"
        mkdir -p "$out/${bundleName}.app/Contents/Resources"

        cp launcher "$out/${bundleName}.app/Contents/MacOS/launcher"

        cat > "$out/${bundleName}.app/Contents/Info.plist" <<'EOF'
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>CFBundleName</key>
          <string>${bundleName}</string>
          <key>CFBundleDisplayName</key>
          <string>${bundleName}</string>
          <key>CFBundleIdentifier</key>
          <string>com.glats.remote.${id}</string>
          <key>CFBundleVersion</key>
          <string>1.0</string>
          <key>CFBundlePackageType</key>
          <string>APPL</string>
          <key>CFBundleExecutable</key>
          <string>launcher</string>
          <key>LSUIElement</key>
          <true/>
          <key>CFBundleIconFile</key>
          <string>GenericNetworkIcon.icns</string>
          <key>NSLocalNetworkUsageDescription</key>
          <string>Remote desktop needs local network access to connect to your machines.</string>
        </dict>
        </plist>
        EOF
      '';
    };

  apps = [
    {
      id = "t14-tigervnc";
      bundleName = "Remote T14";
      legacyBundleName = "remote-t14-tigervnc.app";
      protocol = "vnc";
      viewer = "tigervnc";
      host = "172.16.0.10";
      port = "5900";
    }
    {
      id = "oneplus5";
      bundleName = "Remote oneplus";
      legacyBundleName = "remote-oneplus5.app";
      protocol = "rdp";
      host = "172.16.0.12";
    }
    {
      id = "rog";
      bundleName = "Remote Rog";
      legacyBundleName = "remote-rog.app";
      protocol = "rdp";
      host = "172.16.0.5";
    }
    {
      id = "thinkcentre";
      bundleName = "Remote ThinkCentre";
      legacyBundleName = "remote-thinkcentre.app";
      protocol = "rdp";
      host = "172.16.0.11";
    }
  ];

  appSources = lib.listToAttrs (
    map (app: {
      name = app.id;
      value = mkRemoteApp {
        inherit (app)
          id
          bundleName
          protocol
          host
          ;
        port = app.port or "";
        viewer = app.viewer or "tigervnc";
        username = app.username or config.home.username;
      };
    }) apps
  );

in
{
  home.activation.deployRemoteDesktopApps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    icon_source="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericNetworkIcon.icns"
    lsregister_path="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

    # RED safety gate: do not mutate ~/Applications unless all native inputs exist.
    if [ ! -r "$icon_source" ]; then
      echo "Required native network icon is not readable: $icon_source" >&2
      exit 1
    fi
    if [ ! -x "$lsregister_path" ]; then
      echo "Required LaunchServices registrar is unavailable: $lsregister_path" >&2
      exit 1
    fi

    appsDir="$HOME/Applications"
    mkdir -p "$appsDir"

    ${lib.concatMapStrings (app: ''
      src="${appSources.${app.id}}/${app.bundleName}.app"
      dst="$appsDir/${app.bundleName}.app"

      if [ -L "$dst" ] || [ -e "$dst" ]; then
        /bin/chmod -R u+w "$dst"
        /bin/rm -rf "$dst"
      fi

      /bin/cp -R "$src" "$dst"
      /bin/chmod -R u+w "$dst"
      /bin/cp "$icon_source" "$dst/Contents/Resources/GenericNetworkIcon.icns"

      /usr/bin/xattr -cr "$dst"
      /usr/bin/codesign --force --sign - "$dst"

      # Register with LaunchServices so Spotlight resolves to
      # ~/Applications, not stale /nix/store paths.
      "$lsregister_path" -f "$dst"
    '') apps}

    ${lib.concatMapStrings (app: ''
      legacy="$appsDir/${app.legacyBundleName}"
      if [ -L "$legacy" ] || [ -e "$legacy" ]; then
        /bin/rm -rf "$legacy"
      fi
    '') apps}

    /usr/bin/mdimport "$appsDir"
  '';
}
