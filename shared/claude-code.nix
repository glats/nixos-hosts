# Claude Code Home Manager module
# Deploys Claude Code with Gentle AI assets on all hosts.
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.home.claude-code;

  # Merge base MCPs with extra MCPs, then filter by enabled
  allMcps = config.home.gentle-ai.mcps // config.home.gentle-ai.extraMcps;
  enabledMcps = lib.filterAttrs (name: mcp: mcp.enabled or false) allMcps;

  # Translate OpenCode MCP format to Claude Code .mcp.json format
  # OpenCode: { type = "local"; command = ["cmd", "arg"]; url = "..."; enabled = true; }
  # Claude:  { "mcpServers": { "name": { "type": "stdio"|"http", "command": "...", "args": [...], "url": "..." } } }
  claudeMcpServers = lib.mapAttrs (
    name: mcp:
    if mcp.type == "local" then
      {
        type = "stdio";
        command = builtins.head mcp.command;
        args = builtins.tail mcp.command;
      }
      // (builtins.removeAttrs mcp [
        "type"
        "command"
        "enabled"
      ])
    else if mcp.type == "remote" then
      {
        type = "http";
        url = mcp.url;
      }
      // (builtins.removeAttrs mcp [
        "type"
        "url"
        "enabled"
      ])
    else
      builtins.removeAttrs mcp [ "enabled" ]
  ) enabledMcps;

  # Generate .mcp.json for Claude Code
  mcpJson = pkgs.writeText "claude-mcp.json" (builtins.toJSON { mcpServers = claudeMcpServers; });

  # Generate settings.json with permissions and model
  settingsJson = pkgs.writeText "claude-settings.json" (
    builtins.toJSON {
      model = cfg.model;
      permissions = {
        inherit (cfg.permissions)
          allow
          deny
          ask
          defaultMode
          ;
      };
    }
  );

  # CLAUDE.md source from gentle-ai-assets
  claudeMdSource = "${pkgs.gentle-ai-assets}/share/gentle-ai/claude/sdd-orchestrator.md";

  claudeDir = "${config.home.homeDirectory}/.claude";
in
{
  imports = [
    ./gentle-ai-common.nix
  ];

  options.home.claude-code = {
    enable = mkEnableOption "Claude Code configuration with Gentle AI assets";

    model = mkOption {
      type = types.str;
      default = "claude-sonnet-4-6-20250508";
      description = "Default Claude Code model to use.";
    };

    permissions = mkOption {
      type = types.submodule {
        options = {
          allow = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Commands always allowed without prompting.";
          };
          deny = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Commands always denied.";
          };
          ask = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Commands that always prompt for permission.";
          };
          defaultMode = mkOption {
            type = types.enum [
              "acceptEdits"
              "auto"
              "bypassPermissions"
              "default"
              "dontAsk"
              "plan"
            ];
            default = "default";
            description = "Default permission mode for Claude Code sessions.";
          };
        };
      };
      default = { };
      description = "Permission rules for Claude Code command execution.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      claude-code
      gentle-ai
      engram
    ];

    home.gentle-ai.enable = true;

    home.file = {
      ".claude/settings.json" = {
        force = true;
        source = settingsJson;
      };

      # Project-scope MCP config at repo root (user-scope ~/.claude.json is managed by Claude Code).
      # Claude Code reads .mcp.json from the project root for project-scope MCP servers.
      ".nixos/.mcp.json" = {
        force = true;
        source = mcpJson;
      };
    };

    # Mutable asset deployment.
    # Converts HM symlinks to real copies so Claude Code can write config at runtime.
    # Copies agents/, commands/, personas/, and skills/ from nix store with cmp guard.
    home.activation."deployClaudeCodeAssets" = config.lib.dag.entryAfter [ "linkGeneration" ] ''
      claude_dir="${claudeDir}"

      # Create directory if it doesn't exist (Claude Code may not have run yet)
      mkdir -p "$claude_dir"

      # Make settings.json mutable (replace symlink with real copy)
      settings_file="$claude_dir/settings.json"
      if [ -L "$settings_file" ]; then
        src="$(${pkgs.coreutils}/bin/readlink -f "$settings_file")"
        ${pkgs.coreutils}/bin/cp --remove-destination "$src" "$settings_file"
      fi
      if [ -f "$settings_file" ] && [ ! -w "$settings_file" ]; then
        chmod 644 "$settings_file"
      fi

      # Directory management for agents/, commands/, skills/
      # Handled here (not via home.file) because HM cannot overwrite real dirs with symlinks.
      # Copies files from nix store with per-file cmp guard + orphan cleanup.
      for dir_pair in "agents:${pkgs.gentle-ai-assets}/share/gentle-ai/claude/agents" "commands:${pkgs.gentle-ai-assets}/share/gentle-ai/claude/commands" "skills:${config.home.gentle-ai.skillsSource}"; do
        dir_name="''${dir_pair%%:*}"
        src="''${dir_pair#*:}"
        target="$claude_dir/$dir_name"

        # Skip if source does not exist
        if [ ! -d "$src" ]; then
          continue
        fi

        # Remove symlink if HM managed to create one
        if [ -L "$target" ]; then
          ${pkgs.coreutils}/bin/rm -f "$target"
        fi
        mkdir -p "$target"

        # Copy changed files with cmp guard
        (cd "$src" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
          if [ ! -f "$target/$rel" ] || ! ${pkgs.diffutils}/bin/cmp -s "$src/$rel" "$target/$rel"; then
            mkdir -p "$(dirname "$target/$rel")"
            ${pkgs.coreutils}/bin/cp -f "$src/$rel" "$target/$rel"
            chmod 644 "$target/$rel"
          fi
        done

        # Remove orphaned files (present in target but not in source)
        (cd "$target" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
          if [ ! -f "$src/$rel" ]; then
            rm -f "$target/$rel"
          fi
        done
      done

      # personas/ is optional — copy only if source exists
      personas_src="${pkgs.gentle-ai-assets}/share/gentle-ai/claude/personas"
      if [ -d "$personas_src" ]; then
        personas_target="$claude_dir/personas"
        if [ -L "$personas_target" ]; then
          ${pkgs.coreutils}/bin/rm -f "$personas_target"
        fi
        mkdir -p "$personas_target"
        (cd "$personas_src" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
          if [ ! -f "$personas_target/$rel" ] || ! ${pkgs.diffutils}/bin/cmp -s "$personas_src/$rel" "$personas_target/$rel"; then
            mkdir -p "$(dirname "$personas_target/$rel")"
            ${pkgs.coreutils}/bin/cp -f "$personas_src/$rel" "$personas_target/$rel"
            chmod 644 "$personas_target/$rel"
          fi
        done
        (cd "$personas_target" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
          if [ ! -f "$personas_src/$rel" ]; then
            rm -f "$personas_target/$rel"
          fi
        done
      fi
    '';
  };
}
