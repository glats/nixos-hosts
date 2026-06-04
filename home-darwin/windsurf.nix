{ lib, ... }:
let
  settings = {
    "makefile.configureOnOpen" = false;
    "git.confirmSync" = false;
    "window.zoomLevel" = 0;
    "workbench.editor.enablePreview" = false;
    "files.exclude" = {
      "**/.git" = true;
      "**/.DS_Store" = true;
      "**/.history" = true;
      "**/.pyc" = true;
      "**/.classpath" = true;
      "**/.project" = true;
      "**/.settings" = true;
      "**/.factorypath" = true;
    };
    "search.exclude" = {
      "**/.git" = true;
      "**/node_modules" = true;
      "**/bower_components" = true;
      "**/tmp" = true;
      "**/.history" = true;
      "**/cache" = true;
    };
    "explorer.confirmDelete" = false;
    "explorer.confirmDragAndDrop" = false;
    "go.formatTool" = "gofmt";
    "editor.fontLigatures" = true;
    "explorer.decorations.badges" = false;
    "breadcrumbs.enabled" = false;
    "go.toolsManagement.autoUpdate" = true;
    "windsurf.autocompleteSpeed" = "fast";
    "windsurf.autoExecutionPolicy" = "off";
    "windsurf.chatFontSize" = "default";
    "windsurf.rememberLastModelSelection" = false;
    "windsurf.openRecentConversation" = false;
    "windsurf.explainAndFixInCurrentConversation" = false;
    "windsurf.enableTabToJump" = true;
    "editor.fontFamily" = "'CaskaydiaCove Nerd Font', 'monospace', monospace";
    "window.confirmSaveUntitledWorkspace" = false;
    "editor.minimap.enabled" = false;
    "files.associations" = {
      "*.tool.mod" = "go.mod";
      "*.tool.sum" = "go.sum";
    };
    "material-icon-theme.files.associations" = {
      "*.tool.mod" = "go-mod";
      "*.tool.sum" = "go-mod";
    };
    "diffEditor.hideUnchangedRegions.enabled" = true;
    "workbench.colorTheme" = "One Dark Pro Night Flat";
    "workbench.iconTheme" = "material-icon-theme";
    "search.useIgnoreFiles" = false;
  };
in
{
  # Windsurf stores its settings under ~/Library/Application Support/...
  home.file."Library/Application Support/Windsurf/User/settings.json".text = builtins.toJSON settings;
}
