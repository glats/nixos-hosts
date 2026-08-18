{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "nixos-scripts";
  version = "0.1.0";

  src = ../../bin;

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/bin/lib

    # Install shared library
    cp $src/lib/common.sh $out/bin/lib/
    chmod +x $out/bin/lib/common.sh

    # Install worktree workflow script
    cp $src/code-work $out/bin/
    chmod +x $out/bin/code-work

    # Install utility scripts
    cp $src/add-wireguard-peer $out/bin/
    chmod +x $out/bin/add-wireguard-peer

    cp $src/compare-palette $out/bin/
    chmod +x $out/bin/compare-palette

    cp $src/export-mate-config $out/bin/
    chmod +x $out/bin/export-mate-config

    cp $src/format-nix $out/bin/
    chmod +x $out/bin/format-nix

    cp $src/git-id $out/bin/
    chmod +x $out/bin/git-id

    cp $src/generate-thinkpad-wireguard $out/bin/
    chmod +x $out/bin/generate-thinkpad-wireguard

    cp $src/nixos-build $out/bin/
    chmod +x $out/bin/nixos-build

    cp $src/nixos-build-all $out/bin/
    chmod +x $out/bin/nixos-build-all

    cp $src/opencode2 $out/bin/
    chmod +x $out/bin/opencode2

    cp $src/remove-wireguard-peer $out/bin/
    chmod +x $out/bin/remove-wireguard-peer

    cp $src/sops-rotate-keys $out/bin/
    chmod +x $out/bin/sops-rotate-keys

    cp $src/sync-opencode-remote $out/bin/
    chmod +x $out/bin/sync-opencode-remote

    cp $src/wg-peer $out/bin/
    chmod +x $out/bin/wg-peer

    # webcam excluded: already provided by linux/home/webcam.nix
  '';

  meta = with lib; {
    description = "Shell scripts for NixOS workflow management";
    license = licenses.mit;
  };
}
