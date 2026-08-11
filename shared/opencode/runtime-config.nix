# Generate Home Manager file and activation definitions for a single
# OpenCode runtime (config dir, plugins, commands, skills, AGENTS.md).
{ config
, lib
, pkgs
, providers
, cfg
, runtimeConfig
,
}:

let
  runtimeDir = "${config.home.homeDirectory}/.config/${runtimeConfig.dir}";

  # Per-tool command sources (NOT shared — each tool needs its own)
  opencodeCommandSources = [
    "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/commands"
    "${pkgs.caveman-assets}/share/caveman/commands"
    "${pkgs.ponytail-assets}/share/ponytail/commands"
  ];

  # Merge base MCPs with extra MCPs, then filter by enabled
  allMcps = config.home.ai-assets.mcps // config.home.ai-assets.extraMcps;
  enabledMcps = lib.filterAttrs (name: mcp: mcp.enabled or false) allMcps;

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
    "background-agents.ts" = {
      enable = cfg.plugins.backgroundAgents.enable;
      src = "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/plugins/background-agents.ts";
    };
    "engram.ts" = {
      enable = cfg.plugins.engram.enable;
      src = "${pkgs.engram-assets}/share/engram/opencode/plugins/engram.ts";
    };
    "secret-guard.ts" = {
      enable = cfg.plugins.secretGuard.enable;
      src = "${pkgs.secret-guard-assets}/share/secret-guard/opencode/plugins/secret-guard.ts";
    };
  };
  enabledManagedPlugins = lib.filterAttrs (_: plugin: plugin.enable) managedPlugins;
  disabledManagedPluginNames = lib.attrNames (
    lib.filterAttrs (_: plugin: !plugin.enable) managedPlugins
  );

  # Use providers from centralized providers.nix
  allProviders = providers.allProviders;

  # Generate JSON file with providers, agents, and extra config
  jsonFile = pkgs.writeText "opencode.json" (
    builtins.toJSON (
      {
        agent = cfg.agents;
        provider = allProviders;
        mcp = enabledMcps;
        permission = cfg.permissions;
        instructions = [ ];
        # Managed npm plugins auto-installed by OpenCode at startup
        plugin = cfg.plugins.npmPlugins;
      }
      // lib.optionalAttrs (cfg.disabledProviders != [ ]) { disabled_providers = cfg.disabledProviders; }
    )
  );
in
{
  # HM creates symlinks here; makeOpencodeConfigMutable converts them to real copies at activation time.
  home.file = {
    ".config/${runtimeConfig.dir}/opencode.json" = {
      force = true;
      source = jsonFile;
    };
    # skills/, commands/, and AGENTS.md are managed entirely by makeOpencodeConfigMutable activation
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
    # Plugin .ts files are copied by activation script below, not as symlinks
  };

  # Convert HM symlinks to real files so OpenCode can write config at runtime.
  # NixOS symlink farm changes store paths on every rebuild; real copies avoid
  # false "config changed" signals that cause OpenCode to re-initialize.
  home.activation."makeOpencodeConfigMutable-${runtimeConfig.label}" =
    config.lib.dag.entryAfter [ "linkGeneration" ]
      ''
        runtime_dir="${runtimeDir}"

        mkdir -p "$runtime_dir"

         # Single-file symlinks -> real copies (hash guard via cmp)
         # ALWAYS replace symlinks with real copies — even if content matches,
         # the symlink points to the read-only nix store which OpenCode can't write to.
         # After conversion, also re-copy from nix store if content diverged
         # (e.g. OpenCode modified the file at runtime).
         for file in opencode.json AGENTS.md package.json .gitignore tui.json; do
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

        # AGENTS.md: concatenate all configured sources
        ag_md="${config.home.homeDirectory}/.config/opencode/AGENTS.md"
        > "$ag_md"
        for src in ${lib.concatStringsSep " " config.home.ai-assets.agentsMdSources}; do
          [ -f "$src" ] && [ -s "$src" ] && cat "$src" >> "$ag_md"
        done
        chmod 644 "$ag_md"

        # Patch sdd-apply and sdd-verify: remove <!-- section:model-capable -->
        # marker from line 1 so OpenCode v1.17+ can detect YAML frontmatter.
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
