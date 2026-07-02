# Remote desktop client launchers for Darwin (macOS).
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
      name,
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
              "/w:1680",
              "/h:1050",
              "/gfx:progressive",
              "/bpp:32",
              "/sound:sys:mac",
              "/clipboard",
              "/kbd:layout:0x0000040A,lang:0x040A",
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
              snprintf(logpath, sizeof(logpath), "%s/Library/Logs/remote-${name}.log", pw->pw_dir);
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
      name,
      protocol,
      host,
      port ? "",
      viewer ? "tigervnc",
      username ? config.home.username,
    }:
    let
      launcherC = mkLauncherC {
        inherit
          name
          protocol
          host
          port
          viewer
          username
          ;
      };
    in
    pkgs.stdenv.mkDerivation {
      name = "remote-${name}.app";
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
        mkdir -p $out/remote-${name}.app/Contents/MacOS
        mkdir -p $out/remote-${name}.app/Contents/Resources

        cp launcher $out/remote-${name}.app/Contents/MacOS/launcher

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
      '';
    };

  apps = [
    {
      name = "t14-tigervnc";
      protocol = "vnc";
      viewer = "tigervnc";
      host = "172.16.0.10";
      port = "5900";
    }
    {
      name = "t14-realvnc";
      protocol = "vnc";
      viewer = "realvnc";
      host = "172.16.0.10";
      port = "5900";
    }
    {
      name = "mact2-tigervnc";
      protocol = "vnc";
      viewer = "tigervnc";
      host = "mact2.local";
    }
    {
      name = "mact2-realvnc";
      protocol = "vnc";
      viewer = "realvnc";
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
  home.activation.deployRemoteDesktopApps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    appsDir="$HOME/Applications"
    mkdir -p "$appsDir"

    lsregister_path="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

    ${lib.concatMapStrings (app: ''
      src="${appSources.${app.name}}/remote-${app.name}.app"
      dst="$appsDir/remote-${app.name}.app"

      if [ -L "$dst" ] || [ -e "$dst" ]; then
        rm -rf "$dst"
      fi

      cp -R "$src" "$dst"
      chmod -R +w "$dst"

      xattr -cr "$dst" 2>/dev/null || true
      /usr/bin/codesign --force --sign - "$dst" 2>/dev/null || true

      # Register with LaunchServices so Spotlight resolves to
      # ~/Applications, not stale /nix/store paths.
      if [ -x "$lsregister_path" ]; then
        "$lsregister_path" -f "$dst" 2>/dev/null || true
      fi
    '') apps}

    mdimport "$appsDir" 2>/dev/null || true
  '';
}
