{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "nixos-scripts";
  version = "0.1.0";

  src = ../../bin;

  installPhase = ''
        mkdir -p $out/bin
    
        # Install worktree workflow scripts
        cp $src/work-flow $out/bin/
        chmod +x $out/bin/work-flow
    
        cp $src/start-work $out/bin/
        chmod +x $out/bin/start-work
    
        cp $src/finish-work $out/bin/
        chmod +x $out/bin/finish-work
    
        cp $src/abort-work $out/bin/
        chmod +x $out/bin/abort-work
    
        cp $src/list-work $out/bin/
        chmod +x $out/bin/list-work
    
        # Install git workflow scripts
        cp $src/git-flow $out/bin/
        chmod +x $out/bin/git-flow
    
        cp $src/oc-wt $out/bin/
        chmod +x $out/bin/oc-wt
    
        # Install utility scripts
        cp $src/format-nix $out/bin/
        chmod +x $out/bin/format-nix
    
        cp $src/nixos-build $out/bin/
        chmod +x $out/bin/nixos-build
    
        cp $src/update-gentle-ai $out/bin/
        chmod +x $out/bin/update-gentle-ai
    
        cp $src/gentle-ai-tui $out/bin/
        chmod +x $out/bin/gentle-ai-tui
    
    cp $src/export-mate-config $out/bin/
        chmod +x $out/bin/export-mate-config

        cp $src/xrdp-back-to-picker $out/bin/
        chmod +x $out/bin/xrdp-back-to-picker

        cp $src/sync-gentle-ai $out/bin/
        chmod +x $out/bin/sync-gentle-ai

        cp $src/add_github_secret.sh $out/bin/ 2>/dev/null || true

        # Create symlinks for convenience
        ln -s $out/bin/git-flow $out/bin/git-worktree-flow
  '';

  meta = with lib; {
    description = "Git worktree management scripts for NixOS development";
    license = licenses.mit;
  };
}
