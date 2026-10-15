# Generate the V2 Home Manager runtime configuration and activation steps.
{
  config,
  lib,
  pkgs,
  providers,
  cfg,
  runtimeConfig,
  gentleV2 ? pkgs.gentle-ai,
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
    "opencode-review-transport.ts" =
      "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode-v2/plugins/opencode-review-transport.ts";
    "skill-registry.ts" =
      "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode-v2/plugins/skill-registry.ts";
    "engram.ts" = "${pkgs.engram-assets}/share/engram/opencode-v2/plugins/engram.ts";
  };
  assetTrees = import ../ai-assets-tree.nix { inherit lib pkgs; };
  promptTree = pkgs.runCommand "opencode-owned-context" { } ''
    mkdir -p "$out"
    cp ${v2AgentsMd} "$out/AGENTS.md"
  '';
  legacyPromptTree = pkgs.runCommand "opencode-prior-context" { } ''
    mkdir -p "$out"
    cp ${assetTrees.priorRepo}/AGENTS.md "$out/AGENTS.md"
  '';
  pluginsTree = pkgs.runCommand "opencode-v2-owned-plugins" { } ''
    mkdir -p "$out"
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: source: ''
        cp ${
          lib.escapeShellArg (if builtins.isPath source then builtins.path { path = source; } else source)
        } "$out/${name}"
      '') v2ManagedPlugins
    )}
    chmod -R u+w "$out"
    substituteInPlace "$out/opencode-review-transport.ts" \
      --replace-fail 'Command: "${pkgs.gentle-ai}/bin/gentle-ai"' 'Command: "${gentleV2}/bin/gentle-ai"'
    substituteInPlace "$out/skill-registry.ts" \
      --replace-fail 'const GO_COMMAND = "gentle-ai"' 'const GO_COMMAND = "${gentleV2}/bin/gentle-ai"'
  '';
  legacyLocalPlugins = pkgs.runCommand "opencode-v2-prior-local-plugins" { } ''
    mkdir -p "$out"
    cp ${assetTrees.priorRepo}/shared/opencode/host-config-v2.ts "$out/host-config.ts"
    cp ${assetTrees.priorRepo}/shared/opencode/rtk-v2.ts "$out/rtk.ts"
    cp ${assetTrees.priorPkgs.engram-assets}/share/engram/opencode-v2/plugins/engram.ts "$out/engram.ts"
  '';
  entries =
    (map (source: {
      target = "skills";
      inherit source;
    }) config.home.ai-assets.skillSources)
    ++ (map (source: {
      target = "commands";
      inherit source;
    }) opencodeCommandSources);
  desiredAssets = assetTrees.tree "opencode-v2-owned-assets" (
    entries
    ++ [
      {
        target = "plugins";
        source = pluginsTree;
      }
      {
        target = "";
        source = promptTree;
      }
    ]
  ) false;
  legacyAssets = assetTrees.legacy "v2" [
    {
      target = "plugins";
      source = legacyLocalPlugins;
    }
    {
      target = "";
      source = legacyPromptTree;
    }
  ];
  openfangAssets = assetTrees.tree "openfang-owned-skills" (lib.filter (
    entry: entry.target == "skills"
  ) entries) false;
  legacyOpenfang = assetTrees.legacy "openfang" [ ];

  providerAllowlist = providers.providerAllowlist;

  # V2 global configuration is the only managed OpenCode runtime.
  jsonFile = pkgs.writeText "opencode.json" (
    builtins.toJSON ({
      update = "disable";
      plugins = [ "opencode-claude-subscription@0.1.4" ];
      default_agent = "gentle-orchestrator";
      agents = v2Agents;
      # Fit 2026-10-08: avoid the OpenAI WebSocket interruption route
      # (opencode#53762). This is a mitigation, not a reliability guarantee.
      # Source: opencode.ai/v2/docs/providers#websockets.
      providers.openai.settings.transport = "http";
      # Project the existing NVIDIA inventory into the documented native V2
      # schema; never drop its declaration while retaining its routing IDs.
      providers.nvidia = {
        inherit (providers.nvidiaProvider.nvidia) name models;
        env = [ "NVIDIA_API_KEY" ];
        package = "@opencode/ai/providers/openai-compatible";
        settings = {
          inherit (providers.nvidiaProvider.nvidia.options) baseURL apiKey;
        };
      };
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

        # Refuse modified/foreign collisions and symlink escapes before any
        # asset changes. Bootstrap claims only exact prior 2.5 consumer bytes.
        ${pkgs.nixos-scripts}/bin/ai-assets-reconcile "$runtime_dir" \
          ${desiredAssets} ${legacyAssets} 898d3976e8049a7238eaa7de60bff325c30d2b3d
        # Plugin set: host-config.ts, rtk.ts, engram.ts, skill-registry.ts,
        # opencode-review-transport.ts; the retired SDD adapter is absent.
        mkdir -p "$runtime_dir/node_modules"
        ${pkgs.coreutils}/bin/cp -r ${pkgs.opencode-npm-packages-v2}/lib/node_modules/. "$runtime_dir/node_modules/"
        chmod -R u+w "$runtime_dir/node_modules"
      '';
  home.activation."syncOpencodeSkillsToOpenfang-v2" =
    config.lib.dag.entryAfter [ "setupOpencodePluginRuntime-v2" ]
      ''
        opencode_skills_dir="${config.home.homeDirectory}/.config/opencode-v2/skills"
        openfang_skills_dir="${config.home.homeDirectory}/.openfang/skills"

        ${pkgs.nixos-scripts}/bin/ai-assets-reconcile "${config.home.homeDirectory}/.openfang" \
          ${openfangAssets} ${legacyOpenfang} 898d3976e8049a7238eaa7de60bff325c30d2b3d
      '';
}
