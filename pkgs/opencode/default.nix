{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  unzip,
  zlib,
  openssl,
  icu,
  stdenv,
  ripgrep,
  darwin ? { },
  pkgs,
}:

let
  version = "1.18.18";

  system = stdenvNoCC.hostPlatform.system;
  isLinux = lib.hasSuffix "linux" system;
  isDarwin = lib.hasSuffix "darwin" system;

  platformSrc =
    {
      x86_64-linux = {
        url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64.tar.gz";
        sha256 = "sha256-DN3CIkGLhVNmmQWomAwM2nCI8A2iTYPWrHawHJ/bKq8=";
      };
      aarch64-linux = {
        url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-arm64.tar.gz";
        sha256 = "sha256-3LG17FaHtD+HdJVgAh+SA/OAngzlrkT/m+iuFwg/5Lo=";
      };
      x86_64-darwin = {
        url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-x64.zip";
        sha256 = "sha256-lYG9doOnUoRWF5+xHjN32e9WjhCpNWEaLGci40lFTYM=";
      };
      aarch64-darwin = {
        url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-arm64.zip";
        sha256 = "sha256-fWaL8mSW/shobU5R67GsK9Ljk/DBYgqmlsTCQqnlgGo=";
      };
    }
    .${system} or (throw "Unsupported system: ${system}");

  binPath = lib.makeBinPath (
    [ ripgrep ] ++ lib.optionals (isDarwin && darwin ? sysctl) [ darwin.sysctl ]
  );
in
stdenvNoCC.mkDerivation {
  pname = "opencode";
  inherit version;

  src = fetchurl {
    inherit (platformSrc) url sha256;
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    makeBinaryWrapper
    unzip
  ]
  ++ lib.optionals isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals isLinux [
    zlib
    openssl
    icu
    stdenv.cc.cc.lib
  ];

  dontStrip = true;

  installPhase = ''
    mkdir -p $out/bin
    install -m755 opencode $out/bin/.opencode-unwrapped
    makeBinaryWrapper $out/bin/.opencode-unwrapped $out/bin/opencode \
      --prefix PATH : ${binPath}
  '';

  passthru.updateScript = pkgs.writeScript "update-opencode" ''
    #!/usr/bin/env bash
    set -euo pipefail

    FLAKE_ROOT="$PWD"
    while [ "$FLAKE_ROOT" != "/" ]; do
      if [ -d "$FLAKE_ROOT/.git" ] || [ -f "$FLAKE_ROOT/flake.nix" ]; then
        break
      fi
      FLAKE_ROOT="$(dirname "$FLAKE_ROOT")"
    done

    PKG_DIR="$FLAKE_ROOT/pkgs/opencode"

    if [ ! -f "$PKG_DIR/default.nix" ]; then
      echo "Error: Could not find $PKG_DIR/default.nix"
      echo "Make sure you're running this from within the nixos config repository"
      exit 1
    fi

    latest=$(${pkgs.curl}/bin/curl -s https://api.github.com/repos/anomalyco/opencode/releases/latest | ${pkgs.jq}/bin/jq -r .tag_name | ${pkgs.gnused}/bin/sed 's/^v//')
    current="${version}"

    if [ "$latest" = "null" ] || [ -z "$latest" ]; then
      echo "Error: Could not fetch latest version from GitHub API"
      exit 1
    fi

    if [ "$latest" != "$current" ]; then
      echo "Updating opencode: $current -> $latest"

      declare -a urls=(
        "https://github.com/anomalyco/opencode/releases/download/v$latest/opencode-linux-x64.tar.gz"
        "https://github.com/anomalyco/opencode/releases/download/v$latest/opencode-linux-arm64.tar.gz"
        "https://github.com/anomalyco/opencode/releases/download/v$latest/opencode-darwin-x64.zip"
        "https://github.com/anomalyco/opencode/releases/download/v$latest/opencode-darwin-arm64.zip"
      )

      declare -a sris=()
      for url in "''${urls[@]}"; do
        hash=$(${pkgs.nix}/bin/nix-prefetch-url "$url")
        sri=$(${pkgs.nix}/bin/nix hash convert --hash-algo sha256 --to sri "$hash")
        sris+=("$sri")
      done

      ${pkgs.gnused}/bin/sed -i "s/version = \"$current\";/version = \"$latest\";/" "$PKG_DIR/default.nix"

      # Replace the four sha256 lines in file order (linux x64, linux arm64,
      # darwin x64, darwin arm64). Positional, so the script stays re-runnable.
      ${pkgs.gawk}/bin/awk \
        -v h1="''${sris[0]}" -v h2="''${sris[1]}" -v h3="''${sris[2]}" -v h4="''${sris[3]}" '
        /sha256 = "/ {
          n++
          sub(/sha256 = "sha256-fWaL8mSW/shobU5R67GsK9Ljk/DBYgqmlsTCQqnlgGo="]*"/, "sha256 = \"" (n == 1 ? h1 : n == 2 ? h2 : n == 3 ? h3 : h4) "\"")
        }
        { print }
      ' "$PKG_DIR/default.nix" > "$PKG_DIR/default.nix.tmp"
      mv "$PKG_DIR/default.nix.tmp" "$PKG_DIR/default.nix"

      echo "Updated opencode to $latest"
      echo "Linux x64 hash:    ''${sris[0]}"
      echo "Linux arm64 hash:  ''${sris[1]}"
      echo "Darwin x64 hash:   ''${sris[2]}"
      echo "Darwin arm64 hash: ''${sris[3]}"
      echo "File updated: $PKG_DIR/default.nix"
    else
      echo "opencode is already at the latest version: $current"
    fi
  '';

  meta = with lib; {
    description = "OpenCode - the open source AI coding agent";
    homepage = "https://github.com/anomalyco/opencode";
    license = licenses.mit;
    sourceProvenance = [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "opencode";
  };
}
