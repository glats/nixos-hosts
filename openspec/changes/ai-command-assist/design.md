# Design: ai-command-assist

> **Change**: `ai-command-assist`
> **Phase**: sdd-design
> **Spec**: `openspec/changes/ai-command-assist/spec.md` (domain: home-manager)
> **Prior artifacts**: `exploration.md` (rev 2), `proposal.md` (rev 2)

## Technical Approach

Install `pkgs.shell-gpt` via a new Home Manager module (`home-linux/shell-gpt.nix`)
and configure it declaratively through `home.sessionVariables`. shell-gpt reads
**every config key from an environment variable** before falling back to its
`~/.sgptrc` file (`sgpt/config.py`: `value = os.getenv(key) or super().get(key)`),
so Nix session variables are the native configuration surface — no config file,
no fork, no patch, no custom derivation.

The module targets the **nvidia NIM** OpenAI-compatible endpoint
(`https://integrate.api.nvidia.com/v1`) and reuses the `NVIDIA_API_KEY` already
exported by `shared/opencode.nix` (sops-nix → `programs.zsh.initContent`).
`OPENAI_API_KEY` is mapped to the literal string `"$NVIDIA_API_KEY"` so the
shell resolves it at runtime — no secret is duplicated or stored in the Nix
store.

The module follows the **host-conditional pattern** (`openfang`, `conky-rog`):
it is NOT added to `home-linux/shared-modules.nix`. Each host imports it
explicitly and sets `home.shell-gpt.enable` independently. This keeps the
shared list as the single source of truth and lets hosts pick different
models (nemotron on rog, a lighter model on thinkcentre) or opt out entirely.

## Architecture Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| AD1 | Use `pkgs.shell-gpt` from nixpkgs as-is | Already packaged, battle-tested (10k+ users), `shlex.quote()`-protected execution. Zero maintenance — nixpkgs owns it. Exploration (rev 2) confirmed the earlier "shell=True vulnerability" claim was factually wrong. |
| AD2 | Configure via `home.sessionVariables`, not a config file | shell-gpt's `Config.get()` checks `os.getenv(key)` FIRST. Env vars override `~/.sgptrc`. HM-managed session vars are declarative, per-host, and require no `home.file` activation script. |
| AD3 | `OPENAI_API_KEY = "$NVIDIA_API_KEY"` (literal `$`) | Reuses the sops-nix-exported key already present in interactive shells. The `$` is interpreted by the shell when session variables are sourced, so the secret never enters the Nix store. `NVIDIA_API_KEY` is exported by `shared/opencode.nix` for all Linux hosts. |
| AD4 | Host-conditional import (NOT in `shared-modules.nix`) | Matches the `openfang` / `conky-rog` pattern documented in `shared-modules.nix`'s header comment: "Host-conditional modules are NOT included here and are appended by each caller." Lets rog/thinkcentre/t14 pick different models or disable independently. Keeps the shared list as the single source of truth (no reintroducing the drift the centralization fixed). |
| AD5 | Module exposes `home.shell-gpt.*` options under `home.` namespace | Consistent with `home.openfang.*` (openfang.nix) and `home.opencode.*` (shared/opencode.nix). `home.` is the established option-namespace prefix for this repo's HM modules. |
| AD6 | Set five session variables, not three | The spec's "Module enabled on rog" scenario explicitly verifies `API_BASE_URL`, `OPENAI_API_KEY`, `DEFAULT_MODEL`, `SHELL_INTERACTION`, and `DEFAULT_EXECUTE_SHELL_CMD`. Setting only three would fail `sdd-verify`. Although `SHELL_INTERACTION="true"` is shell-gpt's upstream default, setting it explicitly makes the guarantee independent of upstream defaults and satisfies the spec scenario. `DEFAULT_EXECUTE_SHELL_CMD="false"` enforces the confirmation gate even if upstream changes. |
| AD7 | No `hostName` conditionals inside the module | The spec's "Module follows existing host-conditional pattern" scenario forbids `hostName`, `networking.hostName`, or `lib.mkIf (hostName == ...)` inside the module. Host differentiation is handled entirely at the import site in each host's module list. |
| AD8 | Commented `# home.shell-gpt.enable = false;` in each host file | Serves as in-file documentation of where and how to toggle the module (spec scenario "Disabled comment example in host config"). The commented line has no build effect. |

## Data Flow

```
sops-nix secrets/opencode/nvidia_api_key
  → shared/opencode.nix: programs.zsh.initContent
  → export NVIDIA_API_KEY="$(cat <sops path>)"   [interactive zsh only]

home-linux/shell-gpt.nix (this change)
  ├─ home.shell-gpt.enable = true   [per-host, in hosts/<h>/home/...]
  ├─ home.packages += [ pkgs.shell-gpt ]
  └─ home.sessionVariables =
       API_BASE_URL          = cfg.baseUrl      → sgpt/config.py  (OpenAI client base_url)
       OPENAI_API_KEY        = "$NVIDIA_API_KEY"→ sgpt/handler.py (auth; shell-resolved at source time)
       DEFAULT_MODEL          = cfg.model       → sgpt/config.py  (model id for nvidia NIM)
       SHELL_INTERACTION      = "true"          → enables [E/M/D/A] confirmation prompt
       DEFAULT_EXECUTE_SHELL_CMD = "false"      → never auto-execute; always prompt

Runtime (user invokes sgpt):
  sgpt --shell "list files sorted by size"
    → openai.OpenAI(base_url=$API_BASE_URL, api_key=$OPENAI_API_KEY)
    → chat.completions.create(model=$DEFAULT_MODEL, ...)
    → nvidia NIM returns command text
    → [E]xecute / [M]odify / [D]escribe / [A]bort prompt
    → on [E]: os.system("$SHELL -c " + shlex.quote(cmd))   [injection blocked]
```

### Env Var Mapping

| Nix option | Env var | Read by | Purpose |
|-----------|---------|---------|---------|
| `cfg.baseUrl` | `API_BASE_URL` | `sgpt/config.py` | OpenAI-compatible endpoint (nvidia NIM) |
| (derived) `"$NVIDIA_API_KEY"` | `OPENAI_API_KEY` | `sgpt/handler.py` | Auth — shell-resolves to sops-nix secret |
| `cfg.model` | `DEFAULT_MODEL` | `sgpt/config.py` | Model ID sent to nvidia NIM |
| (constant) `"true"` | `SHELL_INTERACTION` | `sgpt/config.py` | Enable `[E/M/D/A]` confirmation gate |
| (constant) `"false"` | `DEFAULT_EXECUTE_SHELL_CMD` | `sgpt/config.py` | Disable auto-execution; always prompt |

## Interfaces

### Module options (`home.shell-gpt.*`)

```nix
options.home.shell-gpt = {
  enable   = mkEnableOption "ShellGPT AI command assistant";
  model    = mkOption { type = types.str; default = "nvidia/nemotron-3-ultra-550b-a55b"; };
  baseUrl  = mkOption { type = types.str; default = "https://integrate.api.nvidia.com/v1"; };
  provider = mkOption { type = types.str; default = "nvidia"; };  # documentation only
};
```

`provider` is not read by shell-gpt; it documents which NIM-compatible backend
the options target (useful when a future host swaps `baseUrl` to ollama/local).

### Module body (when enabled)

```nix
config = mkIf cfg.enable {
  home.packages = [ pkgs.shell-gpt ];
  home.sessionVariables = {
    API_BASE_URL            = cfg.baseUrl;
    OPENAI_API_KEY          = "$NVIDIA_API_KEY";
    DEFAULT_MODEL           = cfg.model;
    SHELL_INTERACTION        = "true";
    DEFAULT_EXECUTE_SHELL_CMD = "false";
  };
};
```

When disabled (`enable = false`, the default), the module contributes nothing —
no package, no env vars. This satisfies the spec's "Module disabled on
thinkcentre" scenario with no explicit `mkIf` negation needed because `mkIf`
gates the entire `config` block.

### Host import contract

```nix
# rog/thinkcentre (modules.nix uses list-append pattern)
baseModules ++ [ ../../../home-linux/shell-gpt.nix /* ... */ ];

# t14 (omarchy.nix uses imports = [ ... ] inside an attrset)
imports = [ /* ... */ ../../../home-linux/shell-gpt.nix ];

# Per-host enable (commented by default = disabled):
# home.shell-gpt.enable = false;
# home.shell-gpt.model = "nvidia/nemotron-3-ultra-550b-a55b";
```

## File Changes

| Status | Path | Change | Lines |
|--------|------|--------|-------|
| NEW | `home-linux/shell-gpt.nix` | HM module: options + mkIf config | ~22 |
| MODIFIED | `hosts/rog/home/modules.nix` | +1 import line, +2 commented doc lines | +3 |
| MODIFIED | `hosts/thinkcentre/home/modules.nix` | +1 import line, +2 commented doc lines | +3 |
| MODIFIED | `hosts/t14/home/omarchy.nix` | +1 import in `imports` list, +2 commented doc lines | +3 |

**NOT modified**: `home-linux/shared-modules.nix` (spec scenario "Shared module
list exclusion" forbids it), `flake.nix` (spec scenario "No new flake inputs
required" forbids it), `secrets/` (no new secrets — `NVIDIA_API_KEY` already
exists), `overlays/` (no fork).

Total delta: ~31 lines. Well under the 400-line review budget — single PR, no
chaining needed.

### Reference implementation (`home-linux/shell-gpt.nix`)

```nix
{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.home.shell-gpt;
in
{
  options.home.shell-gpt = {
    enable = mkEnableOption "ShellGPT AI command assistant";

    model = mkOption {
      type = types.str;
      default = "nvidia/nemotron-3-ultra-550b-a55b";
      description = "Model ID sent to the OpenAI-compatible endpoint (nvidia NIM by default).";
    };

    baseUrl = mkOption {
      type = types.str;
      default = "https://integrate.api.nvidia.com/v1";
      description = "OpenAI-compatible API base URL.";
    };

    provider = mkOption {
      type = types.str;
      default = "nvidia";
      description = "Documentation-only label for the configured provider.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.shell-gpt ];

    home.sessionVariables = {
      API_BASE_URL = cfg.baseUrl;
      OPENAI_API_KEY = "$NVIDIA_API_KEY";
      DEFAULT_MODEL = cfg.model;
      SHELL_INTERACTION = "true";
      DEFAULT_EXECUTE_SHELL_CMD = "false";
    };
  };
}
```

Pattern lineage: `openfang.nix` (`mkEnableOption` + `mkMerge`/`mkIf` under
`home.*` namespace). Simplified — no `sops.secrets`, no `systemd.user.services`,
no `home.file` activation scripts, because shell-gpt needs none of those.

### Reference host hook (`hosts/rog/home/modules.nix`)

```nix
baseModules
++ [
  ../../../home-linux/shell-gpt.nix
  ../../../home-linux/remote-desktop.nix
  # ...
];

# ShellGPT AI command assistant (uses nvidia NIM nemotron-3-ultra)
# home.shell-gpt.enable = false;
# home.shell-gpt.model = "nvidia/nemotron-3-ultra-550b-a55b";
```

## Testing Strategy

| # | Test | Command | Verifies |
|---|------|---------|----------|
| T1 | Flake evaluation | `nix flake check --no-build` | Option types valid; module imports parse; no new inputs. Spec scenario "Flake evaluation passes with module imported". |
| T2 | Dry build (rog) | `nixos-build dry` (on rog, with `enable = true`) | Module builds into the HM profile; `pkgs.shell-gpt` resolves. |
| T3 | Enabled profile | rebuild + `which sgpt` | Binary present when `enable = true`. |
| T4 | Env vars present | rebuild + `env | grep -E 'API_BASE_URL\|DEFAULT_MODEL\|SHELL_INTERACTION\|DEFAULT_EXECUTE_SHELL_CMD'` | All five session variables set to spec values. |
| T5 | NIM connectivity | `sgpt --shell "echo hello"` | nvidia NIM authenticates via `$NVIDIA_API_KEY`; returns a command. Spec scenario "One-shot command generation". |
| T6 | Confirmation gate | observe `[E/M/D/A]` prompt on T5 | No auto-execution; `DEFAULT_EXECUTE_SHELL_CMD=false` honored. Spec scenario "No auto-execution by default". |
| T7 | Clean disable | set `enable = false`, rebuild, `which sgpt` (expect fail) + `env` has no shell-gpt vars | Spec scenarios "Module disabled on thinkcentre" and "Hosts can be independently disabled". |
| T8 | No custom code | audit repo for `.py`/wrapper scripts referencing shell-gpt | Only `home-linux/shell-gpt.nix` exists. Spec scenario "Module has no custom code". |
| T9 | Shared-list exclusion | inspect `shared-modules.nix` | `./shell-gpt.nix` absent. Spec scenario "Shared module list exclusion". |

T1–T2 are automated gate checks; T3–T8 are manual post-switch verifications; T9
is a static inspection.

## Migration

**Forward**: Edit three host files + create one module file. No data migration.
No secrets rotation (reuses existing `NVIDIA_API_KEY`). Users who want the tool
uncomment the enable line on their host and rebuild.

**Rollback**: Comment out (or delete) the import line in the host file, or set
`home.shell-gpt.enable = false`. No `home.file` artifacts, no systemd units, no
sops entries to clean — the module contributes only a package and env vars,
both removed automatically on the next `home-manager switch`. Per the proposal's
rollback plan, `nixos-build dry` should be run before the re-switch to verify.

## Open Questions

| # | Question | Impact | Resolution path |
|---|----------|--------|-----------------|
| OQ1 | **Version discrepancy**: proposal/exploration cite shell-gpt 1.5.1, but `nixos_nix` MCP search reports `1.4.5` in the current unstable channel. | Low — env-var config API has been stable across 1.3x–1.5x. But if 1.4.5 lacks `DEFAULT_EXECUTE_SHELL_CMD` support, T6 (auto-execute gating) may rely on a different var name. | During `sdd-apply`, run `nix eval .#legacyPackages.x86_64-linux.shell-gpt.meta.version` (or inspect the derivation) to confirm the actual pinned version. If `<1.5`, verify `DEFAULT_EXECUTE_SHELL_CMD` is honored by reading `sgpt/config.py` in the store path; if not, add an upstream-only override or note the env var as no-op. Does not block the design. |
| OQ2 | t14 import is marked "optional". Should t14 actually ship the module? | Low — t14 is a laptop; laptop users may prefer it most. | Decision is per-host scope, not design scope. The design supports either; `tasks.md` should confirm with the user whether t14 gets an uncommented `enable = true` or just the commented stub. |
| OQ3 | Is `NVIDIA_API_KEY` exported for non-interactive (systemd user unit) shells? | Low for this change — `sgpt` is interactive-only. | `shared/opencode.nix` exports it in `programs.zsh.initContent`, which runs for interactive zsh. shell-gpt is never invoked from a unit, so this is fine. Documented here so a future non-interactive use doesn't assume the key is present. |

## Out of Scope (per proposal + spec)

- No custom Python script or wrapper
- No custom Nix package derivation
- No fork or patch of shell-gpt (danger detection deferred to tier-1.5)
- No non-nvidia providers (deferred; `baseUrl`/`model` options already support future swap)
- No new flake inputs
- No execution audit log / allow-deny lists