{ lib, writeText }:

let
  # Layer 2: Platform overlay functions
  # These transform structured Nix attrsets into OpenCode JSON configuration

  # Merge upstream agents with local overrides using recursive update
  mergeAgents = upstream: local:
    lib.recursiveUpdate upstream local;

  # Resolve provider API keys from secret paths at build time
  # providers: attrset of provider configurations
  # keyPaths: attrset mapping provider names to secret file paths
  # This function reads the actual key values from sops-encrypted files
  resolveProviderKeys = providers: keyPaths:
    lib.mapAttrs
      (
        name: cfg:
          let
            secretPath = keyPaths.${name} or null;
          in
          cfg
          // {
            options = cfg.options // {
              apiKey =
                if secretPath != null then
                # Read actual key from secret file at build time
                  builtins.readFile secretPath
                else
                  cfg.options.apiKey or "KEY_NOT_CONFIGURED";
            };
          }
      )
      providers;

  # Generate final opencode.json from structured configuration
  # agents: attrset of agent definitions
  # providers: attrset of provider configurations
  # mcps: attrset of MCP server configurations
  # permissions: attrset of permission rules
  generateOpencodeJson =
    { agents ? { }
    , providers ? { }
    , mcps ? { }
    , permissions ? { }
    ,
    }:
    writeText "opencode.json" (
      builtins.toJSON {
        agent = agents;
        provider = providers;
        mcp = mcps;
        permission = permissions;
      }
    );

  # Generate opencode.json with build-time secret resolution
  # This is the main entry point that handles the full pipeline:
  # 1. Merge base config with overlays
  # 2. Resolve API keys from secret paths
  # 3. Generate final JSON
  generateOpencodeJsonWithSecrets =
    { agents ? { }
    , providers ? { }
    , mcps ? { }
    , permissions ? { }
    , providerSecretPaths ? { }
    ,
    }:
    let
      resolvedProviders = resolveProviderKeys providers providerSecretPaths;
    in
    generateOpencodeJson {
      inherit agents mcps permissions;
      providers = resolvedProviders;
    };

  # Three-layer configuration assembly
  # base: Layer 1 - upstream defaults from gentle-ai-assets
  # platformOverlay: Layer 2 - platform-specific transformations
  # localOverlay: Layer 3 - user customizations and host-specific settings
  assembleConfig =
    { base ? { }
    , platformOverlay ? { }
    , localOverlay ? { }
    ,
    }:
    {
      agents = mergeAgents (mergeAgents (base.agents or { }) (platformOverlay.agents or { })) (localOverlay.agents or { });
      providers = mergeAgents (mergeAgents (base.providers or { }) (platformOverlay.providers or { })) (localOverlay.providers or { });
      mcps = mergeAgents (mergeAgents (base.mcps or { }) (platformOverlay.mcps or { })) (localOverlay.mcps or { });
      permissions = mergeAgents (mergeAgents (base.permissions or { }) (platformOverlay.permissions or { })) (localOverlay.permissions or { });
    };

  # Extract configuration sections from a JSON file
  # Useful for importing from upstream opencode.json.base
  extractFromJson = jsonFile:
    let
      content = builtins.fromJSON (builtins.readFile jsonFile);
    in
    {
      agents = content.agent or { };
      providers = content.provider or { };
      mcps = content.mcp or { };
      permissions = content.permission or { };
    };

  # Validate that the generated config produces valid JSON
  # Returns true if valid, throws error if invalid
  validateConfig = config:
    let
      json = builtins.toJSON config;
      # Attempt to parse back - this will throw if invalid
      parsed = builtins.fromJSON json;
    in
    parsed != null;

  # Create a plugin file derivation
  # pluginName: name of the plugin (e.g., "engram", "background-agents")
  # pluginFile: path to the plugin source file
  # enabled: boolean - whether to include the plugin
  mkPluginFile = { pluginName, pluginFile, enabled ? false }:
    if enabled then
      writeText "${pluginName}.ts" (builtins.readFile pluginFile)
    else
      null;

  # Generate plugin references for opencode.json
  # activePlugins: list of enabled plugin names
  generatePluginRefs = activePlugins:
    map
      (name: {
        name = name;
        enabled = true;
      })
      activePlugins;

in
{
  # Public API exports
  inherit
    generateOpencodeJson
    generateOpencodeJsonWithSecrets
    mergeAgents
    resolveProviderKeys
    assembleConfig
    extractFromJson
    validateConfig
    mkPluginFile
    generatePluginRefs
    ;

  # Convenience alias for backward compatibility
  generate = generateOpencodeJson;
  generateWithSecrets = generateOpencodeJsonWithSecrets;
}
