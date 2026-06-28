{ lib
, stdenvNoCC
, fetchurl
, autoPatchelfHook
, makeBinaryWrapper
, unzip
, zlib
, openssl
, icu
, stdenv
, ripgrep
, darwin ? { }
, pkgs
,
}:

let
  version = "1.17.11";

  system = stdenvNoCC.hostPlatform.system;
  isLinux = lib.hasSuffix "linux" system;
  isDarwin = lib.hasSuffix "darwin" system;

  platformSrc =
    {
      x86_64-linux = {
        url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64.tar.gz";
        sha256 = "sha256-au/Lu38EzbRkK+Ugjdv6uzw9J0+Ba/Qr/3LupcJE3KI=";
      };
      aarch64-linux = {
        url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-arm64.tar.gz";
        sha256 = "sha256-bAroISQBx4+dzd6tNdOFlTx6ROsWFjCTZbWFA9vRtM0=";
      };
      x86_64-darwin = {
        url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-x64.zip";
        sha256 = "sha256-fz5Re7nH5nHo0xH+7PiQzLM2ogoGU/uJU7ahF8l1BwE=";
      };
      aarch64-darwin = {
        url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-arm64.zip";
        sha256 = "sha256-QHI0RgE96oJS7qTxgNcH916AWvVO6FoU/XwSZRO6g0I=";
      };
    }.${system} or (throw "Unsupported system: ${system}");

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

      linux_x64_url="https://github.com/anomalyco/opencode/releases/download/v$latest/opencode-linux-x64.tar.gz"
      linux_arm64_url="https://github.com/anomalyco/opencode/releases/download/v$latest/opencode-linux-arm64.tar.gz"
      darwin_x64_url="https://github.com/anomalyco/opencode/releases/download/v$latest/opencode-darwin-x64.zip"
      darwin_arm64_url="https://github.com/anomalyco/opencode/releases/download/v$latest/opencode-darwin-arm64.zip"

      linux_x64_hash=$(${pkgs.nix}/bin/nix-prefetch-url "$linux_x64_url")
      linux_arm64_hash=$(${pkgs.nix}/bin/nix-prefetch-url "$linux_arm64_url")
      darwin_x64_hash=$(${pkgs.nix}/bin/nix-prefetch-url "$darwin_x64_url")
      darwin_arm64_hash=$(${pkgs.nix}/bin/nix-prefetch-url "$darwin_arm64_url")

      linux_x64_sri=$(${pkgs.nix}/bin/nix hash to-sri --type sha256 "$linux_x64_hash")
      linux_arm64_sri=$(${pkgs.nix}/bin/nix hash to-sri --type sha256 "$linux_arm64_hash")
      darwin_x64_sri=$(${pkgs.nix}/bin/nix hash to-sri --type sha256 "$darwin_x64_hash")
      darwin_arm64_sri=$(${pkgs.nix}/bin/nix hash to-sri --type sha256 "$darwin_arm64_hash")

      ${pkgs.gnused}/bin/sed -i "s/version = \"$current\";/version = \"$latest\";/" "$PKG_DIR/default.nix"
      ${pkgs.gnused}/bin/sed -i "s|sha256-au/Lu38EzbRkK+Ugjdv6uzw9J0+Ba/Qr/3LupcJE3KI=|sha256-$linux_x64_sri|" "$PKG_DIR/default.nix"
      ${pkgs.gnused}/bin/sed -i "s|sha256-bAroISQBx4+dzd6tNdOFlTx6ROsWFjCTZbWFA9vRtM0=|sha256-$linux_arm64_sri|" "$PKG_DIR/default.nix"
      ${pkgs.gnused}/bin/sed -i "s|sha256-fz5Re7nH5nHo0xH+7PiQzLM2ogoGU/uJU7ahF8l1BwE=|sha256-$darwin_x64_sri|" "$PKG_DIR/default.nix"
      ${pkgs.gnused}/bin/sed -i "s|sha256-QHI0RgE96oJS7qTxgNcH916AWvVO6FoU/XwSZRO6g0I=|sha256-$darwin_arm64_sri|" "$PKG_DIR/default.nix"

      echo "Updated opencode to $latest"
      echo "Linux x64 hash:   $linux_x64_sri"
      echo "Linux arm64 hash: $linux_arm64_sri"
      echo "Darwin x64 hash:  $darwin_x64_sri"
      echo "Darwin arm64 hash:$darwin_arm64_sri"
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
