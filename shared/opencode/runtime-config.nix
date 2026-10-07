# Generate the V2 Home Manager runtime configuration and activation steps.
{
  config,
  lib,
  pkgs,
  providers,
  cfg,
  runtimeConfig,
}:

let
  runtimeDir = "${config.home.homeDirectory}/.config/${runtimeConfig.dir}";

  # Per-tool command sources (NOT shared — each tool needs its own)
  opencodeCommandSources = [
    "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/commands"
    "${pkgs.caveman-assets}/share/caveman/commands"
    "${pkgs.ponytail-assets}/share/ponytail/commands"
  ];

  # Merge base MCPs with extra MCPs, then filter by enabled.
  allMcps = config.home.ai-assets.mcps // config.home.ai-assets.extraMcps;

  # MCP children must never inherit proxy env: OpenCode (Bun) honors
  # HTTPS_PROXY/HTTP_PROXY for its own fetches, and MCP children inherit
  # the full parent env. Empty string is falsy in OpenCode's proxy-env
  # handling (no proxy), and `mcp.environment` is spread AFTER the
  # parent env when spawning a local server, so the scrub below always
  # wins. Remote MCPs have no child process — left untouched. Harmless
  # on hosts that never set proxy vars.
  proxyScrubEnv = {
    HTTPS_PROXY = "";
    HTTP_PROXY = "";
    ALL_PROXY = "";
    NO_PROXY = "*";
  };
  enabledMcps = lib.mapAttrs (
    _: mcp:
    if (mcp.type or "local") == "local" then
      mcp
      // {
        environment = {
          PATH = lib.concatStringsSep ":" [
            "${config.home.profileDirectory}/bin"
            "/etc/profiles/per-user/${config.home.username}/bin"
            "/run/current-system/sw/bin"
            "/nix/var/nix/profiles/default/bin"
            "/opt/homebrew/bin"
            "/usr/local/bin"
            "/usr/bin"
            "/bin"
          ];
        }
        // (mcp.environment or { })
        // proxyScrubEnv;
      }
    else
      mcp
  ) (lib.filterAttrs (_: mcp: mcp.enabled or false) allMcps);

  v2Permissions = import ./v2-permissions.nix {
    inherit lib cfg;
    disabledTools = cfg.disabledTools;
  };
  v2Agents = import ./v2-agents.nix {
    inherit lib cfg runtimeDir;
    permissionRules = v2Permissions.rules;
  };
  v2Mcps = import ./v2-mcps.nix {
    inherit lib;
    mcps = enabledMcps;
    browserMcp = cfg.v2.browserMcp;
  };
  v2AgentsMd = pkgs.writeText "opencode-v2-AGENTS.md" (
    lib.concatMapStringsSep "\n\n" builtins.readFile config.home.ai-assets.agentsMdSources
  );
  v2ManagedPlugins = {
    "host-config.ts" = ./host-config-v2.ts;
    "rtk.ts" = ./rtk-v2.ts;
    "sdd-task-result.ts" =
      "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode-v2/plugins/sdd-task-result.ts";
    "opencode-review-transport.ts" =
      "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode-v2/plugins/opencode-review-transport.ts";
    "skill-registry.ts" =
      "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode-v2/plugins/skill-registry.ts";
    "engram.ts" = "${pkgs.engram-assets}/share/engram/opencode-v2/plugins/engram.ts";
  };

  providerAllowlist = providers.providerAllowlist;

  # V2 global configuration is the only managed OpenCode runtime.
  jsonFile = pkgs.writeText "opencode.json" (
    builtins.toJSON ({
      update = "disable";
      plugins = [ "opencode-claude-subscription@0.1.4" ];
      default_agent = "gentle-orchestrator";
      agents = v2Agents;
      permissions = v2Permissions.global;
      mcp = v2Mcps;
      experimental.policies = [
        {
          effect = "deny";
          action = "provider.use";
          resource = "*";
        }
      ]
      ++ map (provider: {
        effect = "allow";
        action = "provider.use";
        resource = provider;
      }) providerAllowlist;
    })
  );
in
{
  home.file.".config/${runtimeConfig.dir}/opencode.json" = {
    force = true;
    source = jsonFile;
  };
  home.file.".config/${runtimeConfig.dir}/cli.json" = {
    # This is generated V2 configuration, not user state. Force replacement
    # so Home Manager does not create another `.backup` on later activations.
    force = true;
    text = builtins.toJSON {
      "$schema" = "https://opencode.ai/cli.json";
    };
  };

  # `backupFileExtension = "backup"` may have left this from an earlier V2
  # activation. Remove only the generated V2 collision before linkGeneration;
  # V1 and all other V2 runtime state remain untouched.
  home.activation."cleanupOpencodeV2CliBackup-${runtimeConfig.label}" =
    config.lib.dag.entryBefore [ "linkGeneration" ]
      ''
        ${pkgs.coreutils}/bin/rm -f "${runtimeDir}/cli.json.backup"
      '';

  home.activation."makeOpencodeConfigMutable-${runtimeConfig.label}" =
    config.lib.dag.entryAfter [ "linkGeneration" ]
      ''
        runtime_dir="${runtimeDir}"
        opencode_json="$runtime_dir/opencode.json"

            mkdir -p "$runtime_dir"
            if [ ! -f "$runtime_dir/AGENTS.md" ] || ! ${pkgs.diffutils}/bin/cmp -s "${v2AgentsMd}" "$runtime_dir/AGENTS.md"; then
              ${pkgs.coreutils}/bin/cp -f "${v2AgentsMd}" "$runtime_dir/AGENTS.md"
              chmod 644 "$runtime_dir/AGENTS.md"
            fi

            if [ -L "$opencode_json" ]; then
              src="$(${pkgs.coreutils}/bin/readlink -f "$opencode_json")"
              ${pkgs.coreutils}/bin/cp --remove-destination "$src" "$opencode_json"
            fi
            if [ -f "$opencode_json" ] && [ ! -w "$opencode_json" ]; then
              chmod 644 "$opencode_json"
            fi
            if [ -f "$opencode_json" ] && ! ${pkgs.diffutils}/bin/cmp -s "${jsonFile}" "$opencode_json"; then
          ${pkgs.coreutils}/bin/cp "${jsonFile}" "$opencode_json"
          chmod 644 "$opencode_json"
        fi
      '';

  # V2 discovers native skills, commands, and adapters from its own mutable
  # tree; the copy/remap workflow remains writable and idempotent.
  home.activation."setupOpencodePluginRuntime-${runtimeConfig.label}" =
    config.lib.dag.entryAfter [ "makeOpencodeConfigMutable-${runtimeConfig.label}" ]
      ''
        runtime_dir="${runtimeDir}"

        commands_dir="$runtime_dir/commands"
          # Replace any store-linked command tree before copying so the V2
          # commands are writable for the remap below.
        [ -L "$commands_dir" ] && ${pkgs.coreutils}/bin/rm -f "$commands_dir"
        [ -d "$commands_dir" ] && chmod -R u+rwX "$commands_dir"
        [ -d "$commands_dir" ] && ${pkgs.coreutils}/bin/rm -rf "$commands_dir"
        mkdir -p "$commands_dir"

        skills_dir="$runtime_dir/skills"
        [ -L "$skills_dir" ] && ${pkgs.coreutils}/bin/rm -f "$skills_dir"
        mkdir -p "$skills_dir"
        for src in ${lib.concatStringsSep " " opencodeCommandSources}; do
          # Do not preserve the source directory mode: `cp -a` would restore
          # its store-derived read-only mode on the writable destination.
          [ -d "$src" ] && ${pkgs.coreutils}/bin/cp -r "$src"/. "$commands_dir/"
        done
        for src in ${lib.concatStringsSep " " config.home.ai-assets.skillSources}; do
          [ -d "$src" ] && ${pkgs.coreutils}/bin/cp -r "$src"/. "$skills_dir/"
        done
         chmod -R u+w "$commands_dir" "$skills_dir"
         ${pkgs.findutils}/bin/find "$commands_dir" "$skills_dir" -type f -exec ${pkgs.gnused}/bin/sed -i 's/subtask/subagent/g' {} +

         # Delegate-only SDD skills are portable upstream assets. OpenCode V2's
         # native subagent tool requires an explicit agent; without it the model
         # falls back to the generic agent and bypasses the phase contract.
         for skill in sdd-init sdd-explore sdd-propose sdd-spec sdd-design sdd-tasks sdd-apply sdd-verify sdd-archive sdd-research; do
           skill_file="$runtime_dir/skills/$skill/SKILL.md"
           marker='<!-- opencode-v2-phase-delegation -->'
           if [ -f "$skill_file" ] && ! ${pkgs.gnugrep}/bin/grep -qF "$marker" "$skill_file"; then
              ${pkgs.coreutils}/bin/printf '\n%s\n## OpenCode V2 phase delegation\nWhen this skill is loaded by another agent, it MUST call the native `subagent` tool with `agent: "%s"`. It MUST NOT select `general` or omit `agent`.\n' "$marker" "$skill" >> "$skill_file"
           fi
         done

        plugins_dir="$runtime_dir/plugins"
        [ -L "$plugins_dir" ] && ${pkgs.coreutils}/bin/rm -f "$plugins_dir"
        mkdir -p "$plugins_dir"
        # Native V2 replaces media handling; these V1-only plugins are an
        # explicit drop set and stale copies must not survive activation.
        ${pkgs.coreutils}/bin/rm -f \
          "$plugins_dir/claude-auth.ts" \
          "$plugins_dir/opencode-warden.ts" \
          "$plugins_dir/opencode-subagent-statusline.ts" \
          "$plugins_dir/opencode-sdd-engram-manage.ts" \
          "$plugins_dir/model-variants.ts" \
          "$plugins_dir/opencode-multimodal.ts"
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: src: ''
            if [ ! -f "$plugins_dir/${name}" ] || ! ${pkgs.diffutils}/bin/cmp -s "${src}" "$plugins_dir/${name}"; then
              ${pkgs.coreutils}/bin/cp -f "${src}" "$plugins_dir/${name}"
              chmod 644 "$plugins_dir/${name}"
            fi
          '') v2ManagedPlugins
        )}
        mkdir -p "$runtime_dir/node_modules"
        ${pkgs.coreutils}/bin/cp -r ${pkgs.opencode-npm-packages-v2}/lib/node_modules/. "$runtime_dir/node_modules/"
        chmod -R u+w "$runtime_dir/node_modules"
      '';
  home.activation."syncOpencodeSkillsToOpenfang-v2" =
    config.lib.dag.entryAfter [ "setupOpencodePluginRuntime-v2" ]
      ''
        opencode_skills_dir="${config.home.homeDirectory}/.config/opencode-v2/skills"
        openfang_skills_dir="${config.home.homeDirectory}/.openfang/skills"

        mkdir -p "$opencode_skills_dir"
        [ -L "$openfang_skills_dir" ] && ${pkgs.coreutils}/bin/rm -f "$openfang_skills_dir"
        mkdir -p "$openfang_skills_dir"

        (cd "$opencode_skills_dir" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
          if [ ! -f "$openfang_skills_dir/$rel" ] || ! ${pkgs.diffutils}/bin/cmp -s "$opencode_skills_dir/$rel" "$openfang_skills_dir/$rel"; then
            mkdir -p "$(dirname "$openfang_skills_dir/$rel")"
            ${pkgs.coreutils}/bin/cp -f "$opencode_skills_dir/$rel" "$openfang_skills_dir/$rel"
            chmod 644 "$openfang_skills_dir/$rel"
          fi
        done

        (cd "$openfang_skills_dir" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
          [ -f "$opencode_skills_dir/$rel" ] || rm -f "$openfang_skills_dir/$rel"
        done
      '';
}
