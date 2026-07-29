{ pkgs, inputs, ... }:
{
  programs.vscode = {
    enable = true;
    # Homebrew cask only — saves ~500MB nix store
    package = null;

    # Allow VS Code to manage marketplace extensions like Copilot
    mutableExtensionsDir = true;

    profiles.default =
      let
        platform = pkgs.stdenv.hostPlatform.system;
        isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
      in
      {
        # Extensions via nix-vscode-extensions (marketplace mirror).
        # Gated behind isDarwin — the flake input is darwin-only and
        # Linux evals would fail trying to resolve the extension set.
        extensions = pkgs.lib.optionals isDarwin (
          with inputs.nix-vscode-extensions.extensions.${platform}.vscode-marketplace;
          [
            golang.go
            jnoortheen.nix-ide
            arrterian.nix-env-selector
            bbenoist.nix
            vue.volar

            # UX
            zhuangtongfa.material-theme
            pkief.material-icon-theme
            jebbs.plantuml
            hediet.vscode-drawio
          ]
        );

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
