# Claude Code Home Manager module
# Deploys Claude Code with Gentle AI assets on all hosts.
{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.home.claude-code;

  # Per-tool command sources (NOT shared — each tool needs its own)
  claudeCommandSources = [
    "${pkgs.gentle-ai-assets}/share/gentle-ai/claude/agents"
    "${pkgs.gentle-ai-assets}/share/gentle-ai/claude/commands"
  ];

  # Merge base MCPs with extra MCPs, then filter by enabled
  allMcps = config.home.ai-assets.mcps // config.home.ai-assets.extraMcps;
  enabledMcps = lib.filterAttrs (name: mcp: mcp.enabled or false) allMcps;

  # Translate OpenCode MCP format to Claude Code .mcp.json format
  # OpenCode: { type = "local"; command = ["cmd", "arg"]; url = "..."; enabled = true; }
  # Claude:  { "mcpServers": { "name": { "type": "stdio"|"http", "command": "...", "args": [...], "url": "..." } } }
  claudeMcpServers = lib.mapAttrs
    (
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
    )
    enabledMcps;

  # Generate .mcp.json for Claude Code
  mcpJson = pkgs.writeText "claude-mcp.json" (builtins.toJSON { mcpServers = claudeMcpServers; });

  # Auto-generate MCP allow rules from configured servers
  # Each server gets mcp__<name>__* so new MCPs don't need manual permission updates
  mcpAllowRules = map (name: "mcp__${name}__*") (builtins.attrNames enabledMcps);
  userAllowRules = cfg.permissions.allow or [ ];

  # Generate settings.json with permissions.
  # Main model is NOT managed here — the claude-code wrapper injects --model sonnet.
  settingsJson = pkgs.writeText "claude-settings.json" (
    builtins.toJSON {
      # Auto-approve project-scope MCPs (.mcp.json)
      # Claude Code bug #62888 — without this, servers only visible in CLI not TUI
      enableAllProjectMcpServers = true;
      # Skip "are you sure?" prompt for dangerous permission modes
      skipDangerousModePermissionPrompt = true;
      # Keep delegated subagents cheap while the main conversation runs on Sonnet.
      env = {
        CLAUDE_CODE_SUBAGENT_MODEL = "haiku";
      };
      permissions = {
        inherit (cfg.permissions)
          deny
          ask
          defaultMode
          additionalDirectories
          ;
        # User rules first, then auto-generated MCP rules appended
        allow = userAllowRules ++ mcpAllowRules;
      };
      # Disable commit attribution.
      # Gentle AI policy: no AI co-author credits in commits.
      attribution = {
        commit = "";
        pr = "";
        sessionUrl = false;
      };
      # Custom rules are injected via CLAUDE.md (agentsMdSources in ai-assets.nix).
      # No customInstructions here — this field does not exist in Claude Code's
      # settings.json schema and is silently ignored (github issue #12573).
    }
  );

  claudeDir = "${config.home.homeDirectory}/.claude";
in
{
  imports = [
    ./ai-assets.nix
  ];

  options.home.claude-code = {
    enable = mkEnableOption "Claude Code configuration with Gentle AI assets";

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
          additionalDirectories = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Directories outside the working dir that Read/Edit/Write can access.";
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

    home.ai-assets.enable = true;

    home.file = {
      ".claude/settings.json" = {
        force = true;
        source = settingsJson;
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
      # Also update if content differs from nix store source (catches changes after first deploy)
      if [ -f "$settings_file" ] && ! ${pkgs.diffutils}/bin/cmp -s "${settingsJson}" "$settings_file"; then
        ${pkgs.coreutils}/bin/cp "${settingsJson}" "$settings_file"
        chmod 644 "$settings_file"
        echo "deployClaudeCodeAssets: updated settings.json from nix store"
      fi
      if [ -f "$settings_file" ] && [ ! -w "$settings_file" ]; then
        chmod 644 "$settings_file"
      fi

      # Merge MCP servers into user-scope ~/.claude.json.
      # Makes MCPs available across all projects/folders. Preserves all other keys.
      claude_json="${config.home.homeDirectory}/.claude.json"
      mcp_json="${mcpJson}"
      if [ ! -f "$claude_json" ]; then
        ${pkgs.coreutils}/bin/cp "$mcp_json" "$claude_json"
        echo "deployClaudeCodeAssets: created $claude_json"
      fi
      if ${pkgs.jq}/bin/jq -s '.[0] * {mcpServers: ((.[0].mcpServers // {}) * .[1].mcpServers)}' "$claude_json" "$mcp_json" > "$claude_json.tmp"; then
        ${pkgs.coreutils}/bin/mv "$claude_json.tmp" "$claude_json"
        echo "deployClaudeCodeAssets: merged MCP servers into $claude_json"
      else
        echo "deployClaudeCodeAssets: ERROR: jq merge failed for $claude_json" >&2
        ${pkgs.coreutils}/bin/rm -f "$claude_json.tmp"
      fi

      # Directory management for command-like directories (agents/, commands/).
      # Handled here (not via home.file) because HM cannot overwrite real dirs with symlinks.
      # Copies files from each source directory with per-file cmp guard + orphan removal.
      for src in ${lib.concatStringsSep " " claudeCommandSources}; do
        if [ ! -d "$src" ]; then
          continue
        fi
        dir_name="$(basename "$src")"
        target="$claude_dir/$dir_name"

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
        done || :

        # Remove orphaned files (present in target but not in source)
        (cd "$target" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
          if [ ! -f "$src/$rel" ]; then
            rm -f "$target/$rel"
          fi
        done || :
      done

      # Skills: N-way union (all skillSources) with cmp guard + union orphan cleanup
      skills_target="$claude_dir/skills"
      if [ -L "$skills_target" ]; then
        ${pkgs.coreutils}/bin/rm -f "$skills_target"
      fi
      mkdir -p "$skills_target"

      skills_sources_list="${lib.concatStringsSep " " config.home.ai-assets.skillSources}"
      for src in $skills_sources_list; do
        if [ -d "$src" ]; then
          (cd "$src" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
            if [ ! -f "$skills_target/$rel" ] || ! ${pkgs.diffutils}/bin/cmp -s "$src/$rel" "$skills_target/$rel"; then
              mkdir -p "$(dirname "$skills_target/$rel")"
              ${pkgs.coreutils}/bin/cp -f "$src/$rel" "$skills_target/$rel"
              chmod 644 "$skills_target/$rel"
            fi
          done
        fi
      done

      # Union orphan cleanup: delete files absent from ALL sources
      (cd "$skills_target" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
        found=0
        for src in $skills_sources_list; do
          [ -f "$src/$rel" ] && { found=1; break; }
        done
        [ "$found" = "0" ] && rm -f "$skills_target/$rel"
      done || :

      # CLAUDE.md: concatenate all configured sources
      claude_md="${config.home.homeDirectory}/.claude/CLAUDE.md"
      > "$claude_md"
      for src in ${lib.concatStringsSep " " config.home.ai-assets.agentsMdSources}; do
        [ -f "$src" ] && [ -s "$src" ] && cat "$src" >> "$claude_md"
      done
      chmod 644 "$claude_md"

      # output-styles/ — copy persona-*.md + output-style-*.md from claude/ root
      # Claude Code uses ~/.claude/output-styles/ for reusable personas/styles
      # https://code.claude.com/docs/en/output-styles
      styles_target="$claude_dir/output-styles"
      mkdir -p "$styles_target"
      for f in ${pkgs.gentle-ai-assets}/share/gentle-ai/claude/persona-*.md ${pkgs.gentle-ai-assets}/share/gentle-ai/claude/output-style-*.md; do
        if [ -f "$f" ]; then
          name=$(basename "$f")
          if [ ! -f "$styles_target/$name" ] || ! ${pkgs.diffutils}/bin/cmp -s "$f" "$styles_target/$name"; then
            ${pkgs.coreutils}/bin/cp -f "$f" "$styles_target/$name"
            chmod 644 "$styles_target/$name"
          fi
        fi
      done

      # Clean Nix build artifacts (left by previous builds or manual operations).
      # Never touches runtime data: sessions/, cache/, projects/, .credentials.json, etc.
      find "$claude_dir" -maxdepth 1 -name '*.backup' -type f -delete 2>/dev/null || true
      find "$claude_dir" -maxdepth 1 -name '*.bak' -type f -delete 2>/dev/null || true
    '';
  };
}
