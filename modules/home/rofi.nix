{ config, pkgs, ... }:

let
  rofiTheme = ''
    * {
      background: #${config.colorScheme.palette.base00};
      background-alt: #${config.colorScheme.palette.base02};
      foreground: #${config.colorScheme.palette.base05};
      foreground-alt: #${config.colorScheme.palette.base03};
      selected: #${config.colorScheme.palette.base02};
      active: #${config.colorScheme.palette.base02};
      urgent: #${config.colorScheme.palette.base08};
      border: 0;
      margin: 0;
      padding: 0;
      spacing: 0;
    }

    window {
      width: 600px;
      background-color: @background;
      border: 2px;
      border-color: @background-alt;
      border-radius: 8px;
    }

    mainbox {
      background-color: @background;
      children: [inputbar, listview];
      spacing: 10px;
      padding: 15px;
    }

    inputbar {
      background-color: @background-alt;
      border-radius: 4px;
      padding: 10px 15px;
      children: [prompt, entry];
      spacing: 10px;
    }

    prompt {
      background-color: transparent;
      text-color: @foreground;
      font: "Sans 14";
    }

    entry {
      background-color: transparent;
      text-color: @foreground;
      font: "Sans 14";
      placeholder: "Type to search...";
      placeholder-color: @foreground-alt;
    }

    listview {
      background-color: @background;
      columns: 1;
      lines: 8;
      fixed-height: false;
      dynamic: true;
      scrollbar: false;
      spacing: 4px;
      padding: 0;
    }

    element {
      background-color: transparent;
      text-color: @foreground;
      padding: 10px 15px;
      border-radius: 4px;
      spacing: 15px;
    }

    element-icon {
      background-color: transparent;
      size: 32px;
    }

    element-text {
      background-color: transparent;
      text-color: @foreground;
      font: "Sans 12";
      vertical-align: 0.5;
    }

    element selected {
      background-color: @selected;
      text-color: @foreground;
    }

    element active {
      background-color: @active;
      text-color: @foreground;
    }

    scrollbar {
      width: 0px;
      border: 0px;
    }
  '';
in

{
  xdg.configFile."rofi/ulauncher-like.rasi".text = rofiTheme;

  programs.rofi = {
    enable = true;
    font = "Sans 12";
    terminal = "mate-terminal";
    theme = "ulauncher-like";

    extraConfig = {
      modi = "drun";
      display-drun = "🔍";
      show-icons = true;
      icon-theme = "Papirus-Dark";
      drun-display-format = "{name} - {comment}";
      drun-match-fields = "name,generic,exec,categories";
      sort = true;
      case-sensitive = false;
      steal-focus = true;
      location = 0;
      anchor = "center";
      disable-history = false;
      max-history-size = 50;
    };
  };
}
