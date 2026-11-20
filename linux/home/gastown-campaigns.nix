{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.home.gastown;

  profile = import ../../shared/opencode/providers-base.nix {
    inherit lib;
    activeProviderName = config.home.opencode.activeProviderName;
  };

  agentSpec =
    id:
    let
      provider = head (splitString "/" id);
    in
    if provider == "openai" then
      "opencode:${id}"
    else if provider == "anthropic" then
      "claude:${head (builtins.match "anthropic/claude-([a-z]+)-.*" id)}"
    else if
      elem provider [
        "ollama-cloud"
        "nvidia"
      ]
    then
      "opencode:${id}"
    else
      throw "gastown-campaigns: no Gas Town agent spec for ${id}";

  roleModel = role: profile.getModelForRole role profile.activeProvider;

  tiers = profile.activeProvider.tiers or null;

  mayorRole = {
    big = "gentle-orchestrator";
    mid = "gentle-ai-verify";
  };

  profileChains =
    tier:
    pkgs.writeText "gastown-chains-${tier}.json" (
      builtins.toJSON (
        if tiers != null then
          {
            mayor = unique (map agentSpec tiers.${tier});
            polecat = unique (map agentSpec tiers.low);
          }
        else
          {
            mayor = [ (agentSpec (roleModel mayorRole.${tier})) ];
            polecat = unique (
              map agentSpec [
                (roleModel "gentle-ai-verify")
                (roleModel "gentle-ai-worker")
              ]
            );
          }
      )
    );

  secretPath = name: optionalString (config.sops.secrets ? ${name}) config.sops.secrets.${name}.path;

  claudeTokenLookup = pkgs.writeText "opencode-claude-token.py" ''
    import json
    import os
    import sqlite3

    db = os.path.expanduser("~/.local/share/opencode/opencode.db")
    try:
        con = sqlite3.connect("file:" + db + "?mode=ro", uri=True)
        row = con.execute(
            "select value from credential where label = ? and active = 1", ("Anthropic",)
        ).fetchone()
        value = row[0] if row else ""
        try:
            value = json.loads(value).get("key", "")
        except Exception:
            pass
        if value.startswith("sk-ant-oat"):
            print(value)
    except Exception:
        pass
  '';

  start = pkgs.writeShellApplication {
    name = "gastown-campaign-start";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.python3
      pkgs.systemd
    ];
    text = ''
      project="$1"
      timeout="$2"
      state="$HOME/.local/state/gastown/swarm/$project"

      if systemctl --user list-units --state=active --no-legend "gts-$project-*.service" | grep -q .; then
        echo "gastown-campaign: $project already runs as a manually started unit; not starting a second supervisor" >&2
        exit 75
      fi

      load() {
        local value=""
        if [ -n "$2" ] && [ -r "$2" ]; then
          value="$(cat "$2")"
        fi
        if [ -n "$value" ]; then
          export "$1=$value"
          echo "$1: loaded" >&2
        fi
      }

      if [ -n "''${GASTOWN_CHAINS_FILE:-}" ] && [ -z "''${GASTOWN_CAMPAIGN_DRYRUN:-}" ]; then
        if ! /run/current-system/sw/bin/gastown-run swarm chains "$project" "$GASTOWN_CHAINS_FILE"; then
          echo "gastown-campaign: $project could not apply the chains from the OpenCode profile (see the error above); not starting" >&2
          exit 78
        fi
      fi

      load OLLAMA_API_KEY "''${OLLAMA_KEY_FILE:-}"
      load NVIDIA_API_KEY "''${NVIDIA_KEY_FILE:-}"

      source=not-needed
      if grep -q '"claude:' "$state/swarm.json" 2>/dev/null; then
        if [ -n "''${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
          source=environment
        elif [ -n "''${CLAUDE_TOKEN_FILE:-}" ] && [ -s "''${CLAUDE_TOKEN_FILE}" ]; then
          CLAUDE_CODE_OAUTH_TOKEN="$(cat "$CLAUDE_TOKEN_FILE")"
          export CLAUDE_CODE_OAUTH_TOKEN
          source=sops-file
        else
          token="$(python3 ${claudeTokenLookup})"
          if [ -n "$token" ]; then
            export CLAUDE_CODE_OAUTH_TOKEN="$token"
            source=opencode-store
          else
            echo "gastown-campaign: $project uses a claude agent but no subscription token is available (set claudeTokenFile or run claude setup-token)" >&2
            exit 78
          fi
        fi
      fi

      if [ -n "''${GASTOWN_CAMPAIGN_DRYRUN:-}" ]; then
        echo "dry run: project=$project claude=$source ollama=''${OLLAMA_API_KEY:+set} nvidia=''${NVIDIA_API_KEY:+set} chains=''${GASTOWN_CHAINS_FILE:-swarm.json}"
        exit 0
      fi

      exec /run/current-system/sw/bin/gastown-run campaign exec --timeout "$timeout" "$project"
    '';
  };

  stateDir = project: "${config.home.homeDirectory}/.local/state/gastown/swarm/${project}";

  campaignModule = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Start this campaign supervisor at boot and stop it cleanly at shutdown.";
      };
      autostart = mkOption {
        type = types.bool;
        default = true;
        description = "Start this campaign supervisor at boot. When false the unit still exists with the chains from the OpenCode profile, and you start it with systemctl --user start gastown-campaign-<project>.";
      };
      timeout = mkOption {
        type = types.str;
        default = "720h";
        description = "Overall runtime limit passed to the supervisor.";
      };
      stopTimeout = mkOption {
        type = types.str;
        default = "120s";
        description = "Time the supervisor gets to shut the swarm down before it is killed.";
      };
      chainsFromProfile = mkOption {
        type = types.bool;
        default = true;
        description = "Before each start, set the Mayor and polecat chains from the active OpenCode profile: Mayor per mayorTier, polecats from the low tier of every provider when the profile has tiers, otherwise from verify then worker.";
      };
      mayorTier = mkOption {
        type = types.enum [
          "big"
          "mid"
        ];
        default = "mid";
        description = "Profile tier for the Mayor when chainsFromProfile is on: \"mid\" (default) uses the mid tier (gentle-ai-verify without tiers) because the big tier builds the plan in OpenCode and the Mayor only dispatches; \"big\" uses the big tier (gentle-orchestrator without tiers).";
      };
      claudeTokenFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "File holding the Claude subscription token; when unset the OpenCode credential store is used.";
      };
    };
  };

  mkService =
    project: c:
    nameValuePair "gastown-campaign-${project}" {
      Unit = {
        Description = "Gas Town campaign supervisor for ${project}";
        ConditionPathExists = [
          "${stateDir project}/swarm.json"
          "!${stateDir project}/STOP"
        ];
        StartLimitIntervalSec = 1800;
        StartLimitBurst = 5;
      };

      Service = {
        Type = "simple";
        ExecStart = "${start}/bin/gastown-campaign-start ${project} ${c.timeout}";
        Environment = [
          "OLLAMA_KEY_FILE=${secretPath "opencode/ollama_api_key"}"
          "NVIDIA_KEY_FILE=${secretPath "opencode/nvidia_api_key"}"
          "CLAUDE_TOKEN_FILE=${optionalString (c.claudeTokenFile != null) c.claudeTokenFile}"
          "GASTOWN_CHAINS_FILE=${optionalString c.chainsFromProfile "${profileChains c.mayorTier}"}"
        ];
        Restart = "on-failure";
        RestartSec = "60s";
        SuccessExitStatus = "75";
        RestartPreventExitStatus = "78";
        TimeoutStopSec = c.stopTimeout;
        KillMode = "control-group";
        MemoryMax = "8G";
        CPUQuota = "400%";
        TasksMax = 2048;
      };

      Install.WantedBy = optional c.autostart "default.target";
    };
in
{
  options.home.gastown.campaigns = mkOption {
    type = types.attrsOf campaignModule;
    default = { };
    description = "Gas Town campaign supervisors started at boot. The swarm must already be initialised with gastown-run swarm init.";
  };

  config = mkIf (cfg.campaigns != { }) {
    home.packages = [ start ];
    systemd.user.enable = true;
    systemd.user.services = mapAttrs' mkService (filterAttrs (_: c: c.enable) cfg.campaigns);
  };
}
