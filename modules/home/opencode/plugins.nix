{ config, lib, pkgs, ... }:

with lib;

{
  options.home.opencode.plugins = {
    backgroundAgents = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable the background-agents plugin.
          
          WARNING: This plugin has known orchestration issues.
          See: https://github.com/Gentleman-Programming/agent-teams-lite/issues/58
          
          Enable only if you understand the risks and have tested in a non-production environment.
        '';
      };
    };

    engram = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable the engram plugin for persistent memory and session management.
          
          This plugin provides:
          - Memory capture and retrieval
          - Session tracking
          - Agent workflow persistence
        '';
      };
    };
  };

  # TUI Plugins submodule
  options.home.opencode.tuiPlugins = mkOption {
    type = types.submodule {
      options = {
        subAgentStatusline = {
          enable = mkEnableOption "sub-agent-statusline TUI plugin";
        };
        sddEngramManage = {
          enable = mkEnableOption "sdd-engram-manage TUI plugin";
        };
      };
    };
    default = {
      subAgentStatusline.enable = false;
      sddEngramManage.enable = false;
    };
    description = ''
      TUI plugins for OpenCode.
      
      These plugins extend the OpenCode TUI with additional features:
      - subAgentStatusline: Sub-agent status visualization in the TUI footer
      - sddEngramManage: SDD engram management commands in TUI
    '';
  };

  # Declare activePlugins as an option so it can be set in config
  options.home.opencode.activePlugins = mkOption {
    type = types.attrsOf types.bool;
    default = { };
    description = ''
      Computed set of active plugins. This is automatically populated
      based on the plugin enable settings.
    '';
    internal = true;
  };

  # Set the actual active plugins in the config section
  config.home.opencode.activePlugins = mkIf config.home.opencode.enable (
    lib.filterAttrs (name: enabled: enabled) {
      background-agents = config.home.opencode.plugins.backgroundAgents.enable;
      engram = config.home.opencode.plugins.engram.enable;
    }
  );
}
