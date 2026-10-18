{
  config,
  lib,
  pkgs,
  providers,
  cfg,
  gentleManaged,
  openfangEnabled,
}:

let
  runtimeDir = "${config.home.homeDirectory}/.config/opencode";
  herdrAssets = config.home.herdr.integration;

  opencodeCommandSources = [
    "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/commands"
    "${pkgs.caveman-assets}/share/caveman/commands"
    "${pkgs.ponytail-assets}/share/ponytail/commands"
  ];

  allMcps = config.home.ai-assets.mcps // config.home.ai-assets.extraMcps;

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
    browserMcp = cfg.browserMcp;
  };
  v2AgentsMd = pkgs.writeText "opencode-AGENTS.md" (
    lib.concatMapStringsSep "\n\n" builtins.readFile config.home.ai-assets.agentsMdSources
  );
  v2ManagedPlugins = {
    "rtk.ts" = ./rtk-v2.ts;
    "opencode-review-transport.ts" =
      "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/plugins/opencode-review-transport.ts";
    "skill-registry.ts" = "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/plugins/skill-registry.ts";
    "engram.ts" = "${pkgs.engram-assets}/share/engram/opencode/plugins/engram.ts";
    "herdr-agent-state.js" = "${herdrAssets}/plugins/herdr-agent-state.js";
  };
  assetTrees = import ../ai-assets-tree.nix { inherit lib pkgs; };
  promptTree = pkgs.runCommand "opencode-owned-context" { } ''
    mkdir -p "$out"
    cp ${v2AgentsMd} "$out/AGENTS.md"
  '';
  pluginsTree = pkgs.runCommand "opencode-owned-plugins" { } ''
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
      --replace-fail 'Command: "${pkgs.gentle-ai}/bin/gentle-ai"' 'Command: "${gentleManaged}/bin/gentle-ai"'
    substituteInPlace "$out/skill-registry.ts" \
      --replace-fail 'const GO_COMMAND = "gentle-ai"' 'const GO_COMMAND = "${gentleManaged}/bin/gentle-ai"'
  '';
  # Root-level herdr OpenCode integration files (TUI plugin and its V2
  # cli.json directory entrypoint), reconciled next to the managed plugins.
  herdrRootTree = pkgs.runCommand "herdr-opencode-root" { } ''
    mkdir -p "$out/herdr-opencode"
    cp ${herdrAssets}/herdr-tui-session.js "$out/"
    cp ${herdrAssets}/herdr-opencode/tui.js "$out/herdr-opencode/"
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
  desiredAssets = assetTrees.tree "opencode-owned-assets" (
    entries
    ++ [
      {
        target = "plugins";
        source = pluginsTree;
      }
      {
        target = "";
        source = herdrRootTree;
      }
      {
        target = "";
        source = promptTree;
      }
    ]
  );
  openfangAssets = assetTrees.tree "openfang-owned-skills" (
    lib.filter (entry: entry.target == "skills") entries
  );

  providerAllowlist = providers.providerAllowlist;

  jsonFile = pkgs.writeText "opencode.json" (
    builtins.toJSON ({
      update = "disable";
      plugins = [
        "opencode-claude-subscription@0.1.4"
        "@slkiser/opencode-quota@5.0.3"
      ];
      default_agent = "gentle-orchestrator";
      agents = v2Agents;
      providers.openai.settings.transport = "http";
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
  home.file.".config/opencode/opencode.json" = {
    force = true;
    source = jsonFile;
  };
  home.file.".config/opencode/cli.json" = {
    force = true;
    text = builtins.toJSON {
      "$schema" = "https://opencode.ai/cli.json";
      plugins = [ "./herdr-opencode" ];
    };
  };
  home.file.".config/opencode/opencode-quota/quota-toast.jsonc" = {
    force = true;
    text = builtins.toJSON {
      enabledProviders = "auto";
      tuiSidebarPanel.enabled = true;
      enableToast = false;
      tuiCompactStatus.enabled = false;
    };
  };
  home.activation.cleanupOpencodeCliBackup = config.lib.dag.entryBefore [ "linkGeneration" ] ''
    ${pkgs.coreutils}/bin/rm -f "${runtimeDir}/cli.json.backup"
  '';

  home.activation.makeOpencodeConfigMutable = config.lib.dag.entryAfter [ "linkGeneration" ] ''
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

  home.activation.setupOpencodePluginRuntime =
    config.lib.dag.entryAfter [ "makeOpencodeConfigMutable" ]
      ''
        runtime_dir="${runtimeDir}"

        # Refuse modified/foreign collisions and symlink escapes before any
        # asset changes. Bootstrap claims only exact prior 2.5 consumer bytes.
        ${pkgs.nixos-scripts}/bin/ai-assets-reconcile "$runtime_dir" \
          ${desiredAssets} ${assetTrees.none} 898d3976e8049a7238eaa7de60bff325c30d2b3d
        # Plugin set: rtk.ts, engram.ts, skill-registry.ts,
        # opencode-review-transport.ts, herdr-agent-state.js.
        mkdir -p "$runtime_dir/node_modules"
        ${pkgs.coreutils}/bin/cp -r ${pkgs.opencode-npm-packages-v2}/lib/node_modules/. "$runtime_dir/node_modules/"
        chmod -R u+w "$runtime_dir/node_modules"
      '';
  home.activation.syncOpencodeSkillsToOpenfang = lib.mkIf openfangEnabled (
    config.lib.dag.entryAfter [ "setupOpencodePluginRuntime" ] ''
      ${pkgs.nixos-scripts}/bin/ai-assets-reconcile "${config.home.homeDirectory}/.openfang" \
        ${openfangAssets} ${assetTrees.none} 898d3976e8049a7238eaa7de60bff325c30d2b3d
    ''
  );
}
