{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;

let
  cfg = config.home.claude-code;

  claudeCommandSources = [
    "${pkgs.gentle-ai-assets}/share/gentle-ai/claude/agents"
    "${pkgs.gentle-ai-assets}/share/gentle-ai/claude/commands"
  ];
  assetTrees = import ./ai-assets-tree.nix { inherit lib pkgs; };
  claudePrompt = pkgs.writeText "claude-managed-prompt.md" (
    lib.concatMapStringsSep "\n\n" builtins.readFile (
      [ "${pkgs.gentle-ai-assets}/share/gentle-ai/claude/persona-neutral-residual.md" ]
      ++ config.home.ai-assets.ruleSources
      ++ [
        "${pkgs.gentle-ai-assets}/share/gentle-ai/claude/orchestrator.md"
        "${pkgs.gentle-ai-assets}/share/gentle-ai/claude/engram-protocol.md"
      ]
      ++ config.home.ai-assets.agentsMdSources
    )
  );
  promptTree = pkgs.runCommand "claude-owned-prompt" { } ''
    mkdir -p "$out"
    cp ${claudePrompt} "$out/CLAUDE.md"
  '';
  desiredAssets = assetTrees.tree "claude-owned-assets" (
    (map (source: {
      target = "skills";
      inherit source;
    }) config.home.ai-assets.skillSources)
    ++ (map (source: {
      target = builtins.baseNameOf source;
      inherit source;
    }) claudeCommandSources)
    ++ [
      {
        target = "";
        source = promptTree;
      }
      {
        target = "output-styles";
        source = "${pkgs.gentle-ai-assets}/share/gentle-ai/claude/output-styles";
      }
    ]
  );

  allMcps = config.home.ai-assets.mcps // config.home.ai-assets.extraMcps;
  enabledMcps = lib.filterAttrs (name: mcp: mcp.enabled or false) allMcps;

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

  mcpJson = pkgs.writeText "claude-mcp.json" (builtins.toJSON { mcpServers = claudeMcpServers; });

  mcpAllowRules = map (name: "mcp__${name}__*") (builtins.attrNames enabledMcps);
  userAllowRules = cfg.permissions.allow or [ ];

  rtkPreToolUse = {
    matcher = "Bash";
    hooks = [
      {
        type = "command";
        command = "rtk hook claude";
        timeout = 5;
      }
    ];
  };
  hasRtkPreToolUse = any (
    entry:
    (entry.matcher or "") == "Bash"
    && any (hook: (hook.command or "") == "rtk hook claude") (entry.hooks or [ ])
  ) cfg.hooks.preToolUse;
  preToolUse = cfg.hooks.preToolUse ++ optional (!hasRtkPreToolUse) rtkPreToolUse;
  gentleAi = "${pkgs.gentle-ai}/bin/gentle-ai";
  reviewHook = "${gentleAi} review stop-hook --agent claude-code";
  gentleHook = matcher: command: timeout: {
    inherit matcher;
    hooks = [
      {
        type = "command";
        inherit command timeout;
      }
    ];
  };
  telemetryHook = matcher: {
    inherit matcher;
    hooks = [
      {
        type = "command";
        command = "${gentleAi} telemetry runtime claude --json";
        timeout = 5;
        async = true;
      }
    ];
  };
  settingsJson = pkgs.writeText "claude-settings.json" (
    builtins.toJSON {
      enableAllProjectMcpServers = true;
      skipDangerousModePermissionPrompt = true;
      outputStyle = "Neutral";
      permissions = {
        inherit (cfg.permissions)
          deny
          ask
          defaultMode
          additionalDirectories
          ;
        allow = userAllowRules ++ mcpAllowRules;
      };
      attribution = {
        commit = "";
        pr = "";
        sessionUrl = false;
      };
      hooks = {
        PreToolUse = preToolUse;
        Stop = [
          (gentleHook "" reviewHook 60)
          (telemetryHook "")
        ];
        SubagentStop = [ (telemetryHook "") ];
        SessionStart = [ (gentleHook "startup|resume|clear|compact" reviewHook 30) ];
        UserPromptSubmit = [
          (gentleHook ""
            "${gentleAi} skill-registry refresh --quiet --no-gitignore --cwd \"\${CLAUDE_PROJECT_DIR:-$PWD}\" || true"
            10
          )
        ];
      };
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

    hooks = mkOption {
      type = types.submodule {
        options = {
          preToolUse = mkOption {
            type = types.listOf types.attrs;
            default = [ ];
            description = "Declarative Claude Code PreToolUse hook entries.";
          };
        };
      };
      default = { };
      description = "Claude Code lifecycle hooks merged into generated settings.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.claude-code ];

    home.ai-assets.enable = true;

    home.file = {
      ".claude/settings.json" = {
        force = true;
        source = settingsJson;
      };
    };

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
      # The initial copy can inherit the read-only Nix store mode. Make it
      # mutable before mv replaces it with the merged user-scope config.
      chmod 644 "$claude_json"
      if ${pkgs.jq}/bin/jq -s '.[0] * {mcpServers: ((.[0].mcpServers // {}) * .[1].mcpServers)}' "$claude_json" "$mcp_json" > "$claude_json.tmp"; then
        ${pkgs.coreutils}/bin/mv -f "$claude_json.tmp" "$claude_json"
        echo "deployClaudeCodeAssets: merged MCP servers into $claude_json"
      else
        echo "deployClaudeCodeAssets: ERROR: jq merge failed for $claude_json" >&2
        ${pkgs.coreutils}/bin/rm -f "$claude_json.tmp"
      fi

      ${pkgs.nixos-scripts}/bin/ai-assets-reconcile "$claude_dir" \
        ${desiredAssets} ${assetTrees.none} ${inputs.gentle-ai-src.rev}

    '';
  };
}
