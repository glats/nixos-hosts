{ lib
, stdenvNoCC
, fetchurl
, pkgs
,
}:

let
  version = "1.42.0";

  system = stdenvNoCC.hostPlatform.system;
  isLinux = lib.hasSuffix "linux" system;
  isDarwin = lib.hasSuffix "darwin" system;

  platformSrc =
    if isLinux then
      {
        url = "https://github.com/Gentleman-Programming/gentle-ai/releases/download/v${version}/gentle-ai_${version}_linux_amd64.tar.gz";
        sha256 = "sha256-MPOuO68430MlWSyEcJzyRphZZFKB4zM69ygLgi6OM1k=";
      }
    else if isDarwin then
      {
        url = "https://github.com/Gentleman-Programming/gentle-ai/releases/download/v${version}/gentle-ai_${version}_darwin_amd64.tar.gz";
        sha256 = "sha256-XSxDRBSqTRBw0SeYeMhOXnqS1+anjorkM4NjBQjAgKg=";
      }
    else
      throw "Unsupported system: ${system}";
in
stdenvNoCC.mkDerivation {
  pname = "gentle-ai";
  inherit version;

  src = fetchurl {
    inherit (platformSrc) url sha256;
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

      linux_url="https://github.com/Gentleman-Programming/gentle-ai/releases/download/v$latest/gentle-ai_$latest\_linux_amd64.tar.gz"
      darwin_url="https://github.com/Gentleman-Programming/gentle-ai/releases/download/v$latest/gentle-ai_$latest\_darwin_amd64.tar.gz"

      linux_hash=$(${pkgs.nix}/bin/nix-prefetch-url "$linux_url")
      darwin_hash=$(${pkgs.nix}/bin/nix-prefetch-url "$darwin_url")

      linux_sri=$(${pkgs.nix}/bin/nix hash to-sri --type sha256 "$linux_hash")
      darwin_sri=$(${pkgs.nix}/bin/nix hash to-sri --type sha256 "$darwin_hash")

      ${pkgs.gnused}/bin/sed -i "s/version = \"$current\";/version = \"$latest\";/" "$PKG_DIR/default.nix"
      ${pkgs.gnused}/bin/sed -i "s|sha256 = \"sha256-HUJs4hZ0GCmcFuqirPl9xhaVUnafdI7YzoGKomyKgz8=\";|sha256 = \"$linux_sri\";|" "$PKG_DIR/default.nix"
      ${pkgs.gnused}/bin/sed -i "s|sha256 = \"sha256-xsTIiNwltRV1v4muEe8kz0/qJFdaeG+QFcqbG5KaIhE=\";|sha256 = \"$darwin_sri\";|" "$PKG_DIR/default.nix"

      echo "Updated gentle-ai to $latest"
      echo "Linux hash: $linux_sri"
      echo "Darwin hash: $darwin_sri"
      echo "File updated: $PKG_DIR/default.nix"
    else
      echo "gentle-ai is already at the latest version: $current"
    fi
  '';

  meta = with lib; {
    description = "AI ecosystem configurator with persistent memory and SDD workflow";
    homepage = "https://github.com/Gentleman-Programming/gentle-ai";
    license = licenses.mit;
    platforms = [
      "x86_64-linux"
      "x86_64-darwin"
    ];
    maintainers = [ ];
  };
}
