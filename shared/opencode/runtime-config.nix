# Generate Home Manager file and activation definitions for an OpenCode runtime.
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
  isV2 = runtimeConfig.version == "v2";

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
      mcp // { environment = (mcp.environment or { }) // proxyScrubEnv; }
    else
      mcp
  ) (lib.filterAttrs (_: mcp: mcp.enabled or false) allMcps);

  v2Agents = import ./v2-agents.nix { inherit lib cfg; };
  v2Permissions = import ./v2-permissions.nix {
    inherit lib cfg;
    disabledTools = cfg.disabledTools;
  };
  v2Mcps = import ./v2-mcps.nix {
    inherit lib;
    mcps = enabledMcps;
  };
  v2AgentsMd = pkgs.writeText "opencode-v2-AGENTS.md" (
    lib.concatMapStringsSep "\n\n" builtins.readFile config.home.ai-assets.agentsMdSources
  );
  v2ManagedPlugins = {
    "rtk.ts" = ./rtk-v2.ts;
    "sdd-task-result.ts" =
      "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode-v2/plugins/sdd-task-result.ts";
    "opencode-review-transport.ts" =
      "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode-v2/plugins/opencode-review-transport.ts";
    "skill-registry.ts" =
      "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode-v2/plugins/skill-registry.ts";
    "engram.ts" = "${pkgs.engram-assets}/share/engram/opencode-v2/plugins/engram.ts";
  };

  # TUI plugins configuration (name -> enabled)
  # Versions come from pkgs.opencode-npm-packages/versions.json
  tuiPluginsConfig = {
    "opencode-subagent-statusline" = {
      enable = cfg.tuiPlugins.subAgentStatusline.enable;
    };
    "opencode-sdd-engram-manage" = {
      enable = cfg.tuiPlugins.sddEngramManage.enable;
    };
  };
  tuiPluginsToInstall = lib.filterAttrs (name: cfg: cfg.enable) tuiPluginsConfig;

  managedPlugins = {
    "model-variants.ts" = {
      enable = cfg.plugins.modelVariants.enable;
      src = "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/plugins/model-variants.ts";
    };
    "opencode-review-transport.ts" = {
      enable = cfg.plugins.opencodeReviewTransport.enable;
      src = "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/plugins/opencode-review-transport.ts";
    };
    "sdd-task-result-artifacts.ts" = {
      enable = cfg.plugins.sddTaskResultArtifacts.enable;
      src = "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/plugins/sdd-task-result-artifacts.ts";
    };
    "skill-registry.ts" = {
      enable = cfg.plugins.skillRegistry.enable;
      src = "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/plugins/skill-registry.ts";
    };
    "engram.ts" = {
      enable = cfg.plugins.engram.enable;
      src = "${pkgs.engram-assets}/share/engram/opencode/plugins/engram.ts";
    };
    "rtk.ts" = {
      enable = cfg.plugins.rtk.enable;
      src = ./rtk.ts;
    };
  };
  enabledManagedPlugins = lib.filterAttrs (_: plugin: plugin.enable) managedPlugins;
  disabledManagedPluginNames = lib.attrNames (
    lib.filterAttrs (_: plugin: !plugin.enable) managedPlugins
  );

  # V1 provider declarations and V1/V2 allowlist policy share this one source.
  allProviders = providers.allProviders;
  providerAllowlist = providers.providerAllowlist;

  # V2 intentionally gets only native global configuration. V1 retains the
  # complete declarative runtime below without sharing its plugins or assets.
  jsonFile = pkgs.writeText "opencode.json" (
    builtins.toJSON (
      if isV2 then
        {
          update = "disable";
          agents = v2Agents;
          permissions = v2Permissions;
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
        }
      else
        {
          agent = cfg.agents;
          provider = allProviders;
          mcp = enabledMcps;
          permission = cfg.permissions;
          instructions = [ ];
          # Managed npm plugins auto-installed by OpenCode at startup
          plugin = cfg.plugins.npmPlugins;
        }
        // {
          disabled_providers = providers.disabledProviders;
        }
        // lib.optionalAttrs (cfg.disabledTools != [ ]) {
          # Globally disabled tools: OpenCode drops these from provider requests
          # (session/llm/request.ts resolveTools filters user.tools[name]==false),
          # so the pruned MCP tool schemas stop costing tokens on every turn.
          tools = builtins.listToAttrs (
            map (name: {
              inherit name;
              value = false;
            }) cfg.disabledTools
          );
        }
        // {
          # OpenCode 1.18.18 compaction keys. keep.tokens/buffer exist only in
          # the unshipped v2 spec draft — do not emit them.
          compaction = {
            inherit (cfg.compaction) auto prune reserved;
          };
        }
    )
  );
in
if isV2 then
  {
    home.file.".config/${runtimeConfig.dir}/opencode.json" = {
      force = true;
      source = jsonFile;
    };
    home.file.".config/${runtimeConfig.dir}/cli.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/cli.json";
    };

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
    # tree. Keep this separate from the V1 plugin runtime so the V1 copy/remap
    # workflow remains writable and idempotent.
    home.activation."setupOpencodePluginRuntime-${runtimeConfig.label}" =
      config.lib.dag.entryAfter [ "makeOpencodeConfigMutable-${runtimeConfig.label}" ]
        ''
          runtime_dir="${runtimeDir}"

          commands_dir="$runtime_dir/commands"
          # Home Manager may have left a store-linked command tree here. Replace
          # it before copying so every V2 command is owned and writable for the
          # V2-only remap below.
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
  }
else
  {

    # HM creates symlinks here; makeOpencodeConfigMutable converts them to real copies at activation time.
    home.file = {
      ".config/${runtimeConfig.dir}/opencode.json" = {
        force = true;
        source = jsonFile;
      };
      # skills and commands are managed entirely by makeOpencodeConfigMutable activation
      # (not via home.file) because HM cannot overwrite existing real directories with symlinks.
      ".config/${runtimeConfig.dir}/package.json" = {
        force = true;
        source = "${pkgs.opencode-npm-packages}/package.json";
      };
      ".config/${runtimeConfig.dir}/.gitignore" = {
        force = true;
        text = ''
          node_modules
          package-lock.json
          bun.lock
        '';
      };
      ".config/${runtimeConfig.dir}/tui.json" = {
        force = true;
        text = builtins.toJSON {
          "$schema" = "https://opencode.ai/tui.json";
          theme = "system";
          plugin = lib.attrNames tuiPluginsToInstall ++ [ "opencode-multimodal" ];
        };
      };
    };

    # Convert HM symlinks to real files so OpenCode can write config at runtime.
    # NixOS symlink farm changes store paths on every rebuild; real copies avoid
    # false "config changed" signals that cause OpenCode to re-initialize.
    home.activation.prepareOpencodeSkillTree = config.lib.dag.entryBefore [ "linkGeneration" ] ''
      skills_target="${runtimeDir}/skills"

      # linkGeneration may need to remove a stale Home Manager link below this
      # tree. It runs before the V1 mutable-copy activation, so restore write
      # access here instead of relying on a later copy or on V2 staging.
      if [ -L "$skills_target" ]; then
        ${pkgs.coreutils}/bin/rm -f "$skills_target"
      fi
      if [ -d "$skills_target" ]; then
        chmod -R u+rwX "$skills_target"
      fi
    '';

    home.activation."makeOpencodeConfigMutable-${runtimeConfig.label}" =
      config.lib.dag.entryAfter [ "linkGeneration" ]
        ''
          runtime_dir="${runtimeDir}"

          mkdir -p "$runtime_dir"

          # OpenCode discovers the repository-root AGENTS.md itself. Remove the
          # formerly managed global file so it cannot duplicate that context.
          ${pkgs.coreutils}/bin/rm -f "$runtime_dir/AGENTS.md"

            # Single-file symlinks -> real copies (hash guard via cmp)
           # ALWAYS replace symlinks with real copies — even if content matches,
           # the symlink points to the read-only nix store which OpenCode can't write to.
           # After conversion, also re-copy from nix store if content diverged
           # (e.g. OpenCode modified the file at runtime).
            for file in opencode.json package.json .gitignore tui.json; do
             target="$runtime_dir/$file"
             if [ -L "$target" ]; then
               src="$(${pkgs.coreutils}/bin/readlink -f "$target")"
               ${pkgs.coreutils}/bin/cp --remove-destination "$src" "$target"
             fi
             # Ensure files are writable (nix store sources are read-only)
             if [ -f "$target" ] && [ ! -w "$target" ]; then
               chmod 644 "$target"
             fi
           done
           # Re-copy opencode.json from nix store if content diverged
           # (OpenCode mutates it at runtime — model selection, provider state, etc.)
           opencode_json="$runtime_dir/opencode.json"
           if [ -f "$opencode_json" ] && ! ${pkgs.diffutils}/bin/cmp -s "${jsonFile}" "$opencode_json"; then
             ${pkgs.coreutils}/bin/cp "${jsonFile}" "$opencode_json"
             chmod 644 "$opencode_json"
             echo "makeOpencodeConfigMutable: refreshed opencode.json from nix store"
           fi

          # Directory management for commands/
          # Handled here (not via home.file) because HM cannot overwrite real dirs with symlinks.
          # N-way union: copy from all sources, then union-based orphan cleanup.
          cmds_target="$runtime_dir/commands"
          if [ -L "$cmds_target" ]; then
            ${pkgs.coreutils}/bin/rm -f "$cmds_target"
          fi
          mkdir -p "$cmds_target"
          for src in ${lib.concatStringsSep " " opencodeCommandSources}; do
            if [ -d "$src" ]; then
              (cd "$src" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
                if [ ! -f "$cmds_target/$rel" ] || ! ${pkgs.diffutils}/bin/cmp -s "$src/$rel" "$cmds_target/$rel"; then
                  mkdir -p "$(dirname "$cmds_target/$rel")"
                  ${pkgs.coreutils}/bin/cp -f "$src/$rel" "$cmds_target/$rel"
                  chmod 644 "$cmds_target/$rel"
                fi
              done
            fi
          done
          # Union orphan cleanup: delete files absent from ALL command sources
          (cd "$cmds_target" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
            found=0
            for src in ${lib.concatStringsSep " " opencodeCommandSources}; do
              [ -f "$src/$rel" ] && { found=1; break; }
            done
            [ "$found" = "0" ] && rm -f "$cmds_target/$rel"
          done || :

          # Skills: N-way union (all skillSources) with cmp guard + union orphan cleanup
          skills_target="$runtime_dir/skills"
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

          # Orphan cleanup: delete files absent from ALL sources
          (cd "$skills_target" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
            found=0
            for src in $skills_sources_list; do
              [ -f "$src/$rel" ] && { found=1; break; }
            done
            [ "$found" = "0" ] && rm -f "$skills_target/$rel"
          done || :

           # Patch sdd-apply and sdd-verify: remove <!-- section:model-capable -->
           # marker from line 1 so OpenCode v1.17+ can detect YAML frontmatter.
           # `sed -i` creates a temporary file beside each source. Ensure every
           # copied skill directory remains user-writable even when its content
           # matched the immutable source and therefore skipped a file copy.
           chmod -R u+rwX "$skills_target"
           for skill in sdd-apply sdd-verify; do
             skill_file="$runtime_dir/skills/$skill/SKILL.md"
            if [ -f "$skill_file" ] && head -1 "$skill_file" | grep -q '^<!-- section:model-capable -->$'; then
              ${pkgs.gnused}/bin/sed -i '1{/^<!-- section:model-capable -->$/d}' "$skill_file"
            elif [ -f "$skill_file" ]; then
              echo "WARNING: $skill model-capable marker not found on line 1 — upstream may have changed format" >&2
            fi
          done

          # Clean Nix build artifacts (left by previous builds or manual operations)
          find "$runtime_dir" -maxdepth 1 -name '*.backup' -type f -delete 2>/dev/null || true
          find "$runtime_dir" -maxdepth 1 -name '*.bak' -type f -delete 2>/dev/null || true
        '';

    # Install plugins and npm deps; runs after symlink conversion.
    home.activation."setupOpencodePluginRuntime-${runtimeConfig.label}" =
      config.lib.dag.entryAfter [ "makeOpencodeConfigMutable-${runtimeConfig.label}" ]
        ''
          runtime_dir="${runtimeDir}"

          mkdir -p "$runtime_dir"

          # Ensure plugins directory is a real directory (not symlink)
          if [ -L "$runtime_dir/plugins" ]; then
            ${pkgs.coreutils}/bin/rm -f "$runtime_dir/plugins"
          fi
          mkdir -p "$runtime_dir/plugins"

          # Remove the legacy background-agents plugin unconditionally.
          # The option was removed in the gentle-ai v2.5.0 alignment, but
          # installations predating that change may still carry the file.
          ${pkgs.coreutils}/bin/rm -f "$runtime_dir/plugins/background-agents.ts"

          # Remove the retired local secret-guard plugin unconditionally.
          ${pkgs.coreutils}/bin/rm -f "$runtime_dir/plugins/secret-guard.ts"

          # Remove Nix-managed plugins that are now disabled.
          ${lib.concatStringsSep "\n" (
            map (pluginName: ''
              ${pkgs.coreutils}/bin/rm -f "$runtime_dir/plugins/${pluginName}"
            '') disabledManagedPluginNames
          )}

          # Copy plugin files from nix store (not symlinks) with hash guard
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (pluginName: plugin: ''
              target="$runtime_dir/plugins/${pluginName}"
              src="${plugin.src}"
              if [ ! -f "$target" ] || ! ${pkgs.diffutils}/bin/cmp -s "$src" "$target"; then
                ${pkgs.coreutils}/bin/cp -f "$src" "$target"
                chmod 644 "$target"
              fi
            '') enabledManagedPlugins
          )}

          # Copy npm packages from Nix store (pre-built, hash-verified)
          mkdir -p "$runtime_dir/node_modules"
          cp -r ${pkgs.opencode-npm-packages}/lib/node_modules/* "$runtime_dir/node_modules/"
          chmod -R u+w "$runtime_dir/node_modules"

          # Install TUI plugins: all are already in node_modules from Nix derivation
          # OpenCode picks them up from tui.json plugin list

          # Workaround for opencode bug: migration gate checks for opencode.db
          # but non-latest channels (stable) use opencode-stable.db, causing
          # migration to re-run on every launch. Symlink stable -> default name.
          # See: https://github.com/anomalyco/opencode/issues/16885
          data_dir="${config.home.homeDirectory}/.local/share/opencode"
          if [ -f "$data_dir/opencode-stable.db" ] && [ ! -e "$data_dir/opencode.db" ]; then
            ln -s "$data_dir/opencode-stable.db" "$data_dir/opencode.db"
           fi

        '';

    # Sync OpenCode skills to OpenFang (cmp-guarded copy + orphan cleanup).
    # OpenFang requires write access to skill dirs (writes skill.toml manifests),
    # so we copy instead of symlink. Runs after makeOpencodeConfigMutable so all
    # OpenCode skills are already deployed, and before setupOpencodePluginRuntime.
    home.activation."syncOpencodeSkillsToOpenfang-${runtimeConfig.label}" =
      config.lib.dag.entryAfter [ "makeOpencodeConfigMutable-${runtimeConfig.label}" ]
        ''
          opencode_skills_dir="${config.home.homeDirectory}/.config/opencode/skills"
          openfang_skills_dir="${config.home.homeDirectory}/.openfang/skills"

          mkdir -p "$opencode_skills_dir"

          # Ensure openfang skills dir exists as a real directory
          if [ -L "$openfang_skills_dir" ]; then
            ${pkgs.coreutils}/bin/rm -f "$openfang_skills_dir"
          fi
          mkdir -p "$openfang_skills_dir"

          # Copy changed files with cmp guard
          (cd "$opencode_skills_dir" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
            if [ ! -f "$openfang_skills_dir/$rel" ] || ! ${pkgs.diffutils}/bin/cmp -s "$opencode_skills_dir/$rel" "$openfang_skills_dir/$rel"; then
              mkdir -p "$(dirname "$openfang_skills_dir/$rel")"
              ${pkgs.coreutils}/bin/cp -f "$opencode_skills_dir/$rel" "$openfang_skills_dir/$rel"
              chmod 644 "$openfang_skills_dir/$rel"
            fi
          done

          # Orphan cleanup: remove files in openfang/skills not in opencode/skills
          (cd "$openfang_skills_dir" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
            if [ ! -f "$opencode_skills_dir/$rel" ]; then
              rm -f "$openfang_skills_dir/$rel"
            fi
          done
        '';
  }
