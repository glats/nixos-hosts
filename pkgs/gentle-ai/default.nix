{ lib, stdenvNoCC, fetchurl, pkgs }:

stdenvNoCC.mkDerivation rec {
  pname = "gentle-ai";
  version = "1.21.0";

  src = fetchurl {
    url = "https://github.com/Gentleman-Programming/gentle-ai/releases/download/v${version}/gentle-ai_${version}_linux_amd64.tar.gz";
    sha256 = "sha256-zSkg9YFqnLqq7SGxis1OspWINj0lR51Wo1GXAVQ7pK0=";
  };

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    cp gentle-ai $out/bin/
    chmod +x $out/bin/gentle-ai
  '';

  passthru.updateScript = pkgs.writeScript "update-gentle-ai" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Find the flake root (where .nixos or flake.nix exists)
    FLAKE_ROOT="$PWD"
    while [ "$FLAKE_ROOT" != "/" ]; do
      if [ -d "$FLAKE_ROOT/.git" ] || [ -f "$FLAKE_ROOT/flake.nix" ]; then
        break
      fi
      FLAKE_ROOT="$(dirname "$FLAKE_ROOT")"
    done
    
    PKG_DIR="$FLAKE_ROOT/pkgs/gentle-ai"
    
    if [ ! -f "$PKG_DIR/default.nix" ]; then
      echo "Error: Could not find $PKG_DIR/default.nix"
      echo "Make sure you're running this from within the nixos config repository"
      exit 1
    fi
    
    latest=$(${pkgs.curl}/bin/curl -s https://api.github.com/repos/Gentleman-Programming/gentle-ai/releases/latest | ${pkgs.jq}/bin/jq -r .tag_name | ${pkgs.gnused}/bin/sed 's/^v//')
    current="${version}"
    
    if [ "$latest" = "null" ] || [ -z "$latest" ]; then
      echo "Error: Could not fetch latest version from GitHub API"
      exit 1
    fi
    
    if [ "$latest" != "$current" ]; then
      echo "Updating gentle-ai: $current -> $latest"
      
      url="https://github.com/Gentleman-Programming/gentle-ai/releases/download/v$latest/gentle-ai_$latest\_linux_amd64.tar.gz"
      hash=$(${pkgs.nix}/bin/nix-prefetch-url "$url")
      
      # Update version and hash in the file
      ${pkgs.gnused}/bin/sed -i "s/version = \"$current\";/version = \"$latest\";/" "$PKG_DIR/default.nix"
      ${pkgs.gnused}/bin/sed -i "s|sha256 = \".*\";|sha256 = \"$hash\";|" "$PKG_DIR/default.nix"
      
      echo "Updated gentle-ai to $latest with hash $hash"
      echo "File updated: $PKG_DIR/default.nix"
    else
      echo "gentle-ai is already at the latest version: $current"
    fi
  '';

  meta = with lib; {
    description = "AI ecosystem configurator with persistent memory and SDD workflow";
    homepage = "https://github.com/Gentleman-Programming/gentle-ai";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
}
