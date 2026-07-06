{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "nixos-scripts";
  version = "0.1.0";

  src = ../../bin;

  installPhase = ''
    mkdir -p $out/bin

    # Install worktree workflow script
    cp $src/code-work $out/bin/
    chmod +x $out/bin/code-work

    # Install utility scripts
    cp $src/format-nix $out/bin/
    chmod +x $out/bin/format-nix

    cp $src/nixos-build $out/bin/
    chmod +x $out/bin/nixos-build

    cp $src/export-mate-config $out/bin/
    chmod +x $out/bin/export-mate-config
  '';

  meta = with lib; {
    description = "Git worktree management scripts for NixOS development";
    license = licenses.mit;
  };
}
