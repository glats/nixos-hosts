{ lib
, stdenvNoCC
, fetchurl
, pkgs
,
}:

let
  version = "1.16.3";

  system = stdenvNoCC.hostPlatform.system;
  isLinux = lib.hasSuffix "linux" system;
  isDarwin = lib.hasSuffix "darwin" system;

  platformSrc =
    if isLinux then
      {
        url = "https://github.com/Gentleman-Programming/engram/releases/download/v${version}/engram_${version}_linux_amd64.tar.gz";
        sha256 = "sha256-AWt+dfeI7vqyAmbL/kcthsiwjnKPr6ojecnKqzQpWuk=";
      }
    else if isDarwin then
      {
        url = "https://github.com/Gentleman-Programming/engram/releases/download/v${version}/engram_${version}_darwin_amd64.tar.gz";
        sha256 = "sha256-4O9b5YZ1xak1G5m+S+KbhUMTuqLXXRr4UkbwGas85aA=";
      }
    else
      throw "Unsupported system: ${system}";
in
stdenvNoCC.mkDerivation {
  pname = "engram";
  inherit version;

  src = fetchurl {
    inherit (platformSrc) url sha256;
  };

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    cp engram $out/bin/
    chmod +x $out/bin/engram
  '';

  passthru.updateScript = pkgs.writeScript "update-engram" ''
    #!/usr/bin/env bash
    set -euo pipefail

    FLAKE_ROOT="$PWD"
    while [ "$FLAKE_ROOT" != "/" ]; do
      if [ -d "$FLAKE_ROOT/.git" ] || [ -f "$FLAKE_ROOT/flake.nix" ]; then
        break
      fi
      FLAKE_ROOT="$(dirname "$FLAKE_ROOT")"
    done

    PKG_DIR="$FLAKE_ROOT/pkgs/engram"

    if [ ! -f "$PKG_DIR/default.nix" ]; then
      echo "Error: Could not find $PKG_DIR/default.nix"
      echo "Make sure you're running this from within the nixos config repository"
      exit 1
    fi

    latest=$(${pkgs.curl}/bin/curl -s https://api.github.com/repos/Gentleman-Programming/engram/releases/latest | ${pkgs.jq}/bin/jq -r .tag_name | ${pkgs.gnused}/bin/sed 's/^v//')
    current="${version}"

    if [ "$latest" = "null" ] || [ -z "$latest" ]; then
      echo "Error: Could not fetch latest version from GitHub API"
      exit 1
    fi

    if [ "$latest" != "$current" ]; then
      echo "Updating engram: $current -> $latest"

      linux_url="https://github.com/Gentleman-Programming/engram/releases/download/v$latest/engram_$latest\_linux_amd64.tar.gz"
      darwin_url="https://github.com/Gentleman-Programming/engram/releases/download/v$latest/engram_$latest\_darwin_amd64.tar.gz"

      linux_hash=$(${pkgs.nix}/bin/nix-prefetch-url "$linux_url")
      darwin_hash=$(${pkgs.nix}/bin/nix-prefetch-url "$darwin_url")

      linux_sri=$(${pkgs.nix}/bin/nix hash to-sri --type sha256 "$linux_hash")
      darwin_sri=$(${pkgs.nix}/bin/nix hash to-sri --type sha256 "$darwin_hash")

      ${pkgs.gnused}/bin/sed -i "s/version = \"$current\";/version = \"$latest\";/" "$PKG_DIR/default.nix"
      ${pkgs.gnused}/bin/sed -i "s|sha256 = \"sha256-AWt+dfeI7vqyAmbL/kcthsiwjnKPr6ojecnKqzQpWuk=\";|sha256 = \"$linux_sri\";|" "$PKG_DIR/default.nix"
      ${pkgs.gnused}/bin/sed -i "s|sha256 = \"sha256-4O9b5YZ1xak1G5m+S+KbhUMTuqLXXRr4UkbwGas85aA=\";|sha256 = \"$darwin_sri\";|" "$PKG_DIR/default.nix"

      echo "Updated engram to $latest"
      echo "Linux hash: $linux_sri"
      echo "Darwin hash: $darwin_sri"
      echo "File updated: $PKG_DIR/default.nix"
    else
      echo "engram is already at the latest version: $current"
    fi
  '';

  meta = with lib; {
    description = "Persistent memory system for AI coding agents";
    homepage = "https://github.com/Gentleman-Programming/engram";
    license = licenses.mit;
    platforms = [
      "x86_64-linux"
      "x86_64-darwin"
    ];
    maintainers = [ ];
  };
}
