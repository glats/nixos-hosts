{
  pkgs,
  inputs,
  lib,
  ...
}:
{
  programs.vscode = {
    enable = true;
    package =
      let
        # Backport of unstable's fix for nixpkgs#584492 while nixos-26.05 lacks it.
        # VSCode 1.144 moved the bundled ripgrep from @vscode/ripgrep to
        # @vscode/ripgrep-universal, shipped outside node_modules.asar, so
        # 26.05's hardcoded rm/ln path no longer exists and patchPhase fails.
        patch-584492 =
          if lib.versionAtLeast pkgs.vscode.version "1.122.0" && pkgs.stdenv.hostPlatform.isLinux then
            let
              ripgrepSystem =
                if pkgs.stdenv.hostPlatform.isx86_64 then
                  "linux-x64"
                else if pkgs.stdenv.hostPlatform.isAarch64 then
                  "linux-arm64"
                else
                  throw "unsupported system for vscode ripgrep-universal: ${pkgs.stdenv.hostPlatform.system}";
            in
            old:
            (
              builtins.replaceStrings
                [
                  ''asar extract "$packed" "$unpacked"''
                  "resources/app/node_modules/@vscode/ripgrep/bin/rg"
                ]
                [
                  (''
                    asar extract "$packed" "$unpacked"
                              if [ -d "$packed.unpacked" ]; then
                                cp -a "$packed.unpacked/." "$unpacked/"
                              fi'')
                  "resources/app/node_modules/@vscode/ripgrep-universal/bin/${ripgrepSystem}/rg"
                ]
                old.postPatch
              + ''

                rm -rf "resources/app/node_modules.asar.unpacked"
                ln -rs "$unpacked" "resources/app/node_modules.asar.unpacked"''
            )
          else
            old: old.postPatch;
      in
      pkgs.vscode.overrideAttrs (old: {
        postPatch = patch-584492 old;
      });

    mutableExtensionsDir = true;

    profiles.default = {
      extensions =
        with inputs.nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.vscode-marketplace; [
          golang.go
          jnoortheen.nix-ide
          arrterian.nix-env-selector
          bbenoist.nix
          vue.volar
          zhuangtongfa.material-theme
          pkief.material-icon-theme
          jebbs.plantuml
          hediet.vscode-drawio
        ];

      userSettings = {
        "files.associations" = {
          "*.tool.mod" = "go.mod";
          "*.tool.sum" = "go.sum";
          "*.mod.tmpl" = "go.mod";
        };
        "material-icon-theme.files.associations" = {
          "*.tool.mod" = "go-mod";
          "*.tool.sum" = "go-mod";
        };
        "workbench.colorTheme" = "One Dark Pro Night Flat";
        "workbench.iconTheme" = "material-icon-theme";
        "git.confirmSync" = false;
        "window.zoomLevel" = 0;
        "workbench.editor.enablePreview" = false;
        "workbench.startupEditor" = "newUntitledFile";
        "files.exclude" = {
          "**/.git" = true;
          "**/.DS_Store" = true;
          "**/.history" = true;
          "**/.pyc" = true;
          "**/.classpath" = true;
          "**/.project" = true;
          "**/.settings" = true;
          "**/.factorypath" = true;
          "**/bower_components" = true;
          "**/tmp" = true;
        };
        "search.exclude" = {
          "**/.git" = true;
          "**/node_modules" = true;
          "**/bower_components" = true;
          "**/tmp" = true;
          "**/.history" = true;
        };
        "window.titleBarStyle" = "custom";
        "explorer.confirmDelete" = false;
        "explorer.confirmDragAndDrop" = false;
        "go.docsTool" = "gogetdoc";
        "go.formatTool" = "gofmt";
        "go.autocompleteUnimportedPackages" = true;
        "editor.fontLigatures" = true;
        "explorer.decorations.badges" = false;
        "breadcrumbs.enabled" = false;
        "editor.minimap.enabled" = false;
        "go.toolsManagement.autoUpdate" = true;
        "github.authentication.useLocalServer" = true;
        "editor.fontFamily" = "'CaskaydiaCove Nerd Font','monospace', monospace";
        "chat.viewSessions.orientation" = "stacked";
      };
    };
  };
}
