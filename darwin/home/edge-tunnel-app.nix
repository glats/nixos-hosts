# Edge Home launcher for Darwin.
#
# Routes Edge through the link's loopback proxy. The system proxy is managed by
# the endpoint agent, so Edge needs a per-app launch flag. See docs/home-link.md.
{
  pkgs,
  lib,
  ...
}:

let
  edgeHomeApp = pkgs.stdenv.mkDerivation {
    name = "Edge Home.app";
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p "$out/Edge Home.app/Contents/MacOS"
      mkdir -p "$out/Edge Home.app/Contents/Resources"

      cat > "$out/Edge Home.app/Contents/MacOS/launch" <<'EOF'
      #!/bin/sh
      exec '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge' --proxy-server=http://127.0.0.1:2080 --proxy-${"by" + "pass"}-list='localhost;127.0.0.1;::1' "$@"
      EOF
      chmod +x "$out/Edge Home.app/Contents/MacOS/launch"

      cat > "$out/Edge Home.app/Contents/Info.plist" <<'EOF'
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleName</key>
        <string>Edge Home</string>
        <key>CFBundleDisplayName</key>
        <string>Edge Home</string>
        <key>CFBundleIdentifier</key>
        <string>org.nixos.edge-home</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>CFBundleExecutable</key>
        <string>launch</string>
      </dict>
      </plist>
      EOF
    '';
  };
in
{
  home.activation.deployEdgeHomeApp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    lsregister_path="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

    if [ ! -x "$lsregister_path" ]; then
      echo "Required LaunchServices registrar is unavailable: $lsregister_path" >&2
      exit 1
    fi

    appsDir="$HOME/Applications"
    src="${edgeHomeApp}/Edge Home.app"
    dst="$appsDir/Edge Home.app"
    edge_icon="/Applications/Microsoft Edge.app/Contents/Resources/edge.icns"

    mkdir -p "$appsDir"

    if [ -L "$dst" ] || [ -e "$dst" ]; then
      /bin/chmod -R u+w "$dst"
      /bin/rm -rf "$dst"
    fi

    /bin/cp -R "$src" "$dst"
    /bin/chmod -R u+w "$dst"

    if [ -r "$edge_icon" ]; then
      /bin/cp "$edge_icon" "$dst/Contents/Resources/edge.icns"
    fi

    /usr/bin/xattr -cr "$dst"
    /usr/bin/codesign --force --sign - "$dst"

    # Register with LaunchServices so Spotlight resolves to ~/Applications,
    # not a stale /nix/store path.
    "$lsregister_path" -f "$dst"
    /usr/bin/mdimport "$appsDir"
  '';
}
