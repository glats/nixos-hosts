# Exploration: optimize-zsh-startup-time

## Problem

Ghostty opens but the prompt takes ~1.3s steady-state (~13s on first launch after boot,
cold caches). Measured on mact2 (Intel Mac, macOS, zsh 5.9.1) with
`/usr/bin/time zsh -ic exit` and timestamped xtrace.

### Measured breakdown

| Block | Cost | Source |
|---|---|---|
| `/etc/zshrc` (nix-darwin defaults) | ~0.63s | Never overridden by flake |
| mise block in HM `initContent` | ~0.56s | Runs every shell |
| Prezto + plugins + ghostty integration | ~0.09s | OK |

Verified via `NOSYSZSHRC=1` bisects and ZDOTDIR copy experiments:
- Without `/etc/zshrc`: 1.3s → 0.65s
- Without mise block: 0.65s → 0.09s
- Without prezto: 0.65s → 0.07s

## Root Causes

1. **Double shell init from nix-darwin defaults.** The flake never sets
   `programs.zsh` at system level, so nix-darwin defaults apply
   (verified in pinned source `modules/programs/zsh/default.nix:58`):
   - `promptInit = "autoload -U promptinit && promptinit && prompt suse && setopt prompt_sp"`
     → second prompt system competing with prezto's.
   - `enableCompletion = true` → `compinit` #1 + `bashcompinit` in every shell;
     prezto's `completion` pmodule then runs `compinit` #2 (~750ms combined
     compaudit/compdump scans in trace).
   - `interactiveShellInit` carries nix-homebrew's `eval "$(brew shellenv)"` — must be preserved.
2. **mise maintenance in every shell** (`darwin/home/shell.nix:41-79`):
   `eval "$(mise activate zsh)"` + `mise install` + `mise reshim` per shell start.
   mise docs state reshim runs automatically on tool install/update/remove;
   per-shell invocations are pure waste (~150ms). Activate eval itself costs
   ~120-280ms (jdx/mise#6279: activate ≈ 80-100ms vs 47ms shims on first prompt).
3. **Broken syntax-highlighting styles** (`shared/shell-aliases.nix:85-101`):
   17 `ZSH_HIGHLIGHT_STYLES[...]=` assignments execute before
   zsh-syntax-highlighting loads → `assignment to invalid subscript range`
   error; custom colors silently never applied. Affects darwin AND linux hosts
   (shared file).

## External Research (MCP-verified)

- **zsh best practice** (multiple sources: digitalblake.com, mikekasberg.com,
  openreplay): call `compinit` exactly ONCE per session; every extra call is
  waste. Target <200ms startup. Cache expensive `eval "$(tool init)"`
  invocations keyed on binary mtime instead of forking every shell.
- **mise official docs** (mise.jdx.dev/dev-tools/shims.html,
  cli/reshim.html, troubleshooting):
  - "`mise` already runs a reshim anytime a tool is installed/updated/removed,
    so you don't need to use it for those scenarios."
  - For interactive use, PATH activation (`mise activate`) is recommended over
    shims; performance difference is a few ms per prompt.
  - `mise activate --shims` does NOT support `[env]` vars from mise.toml —
    user config has `[env] MISE_NODE_COREPACK = "true"` → must keep full activate.
  - hook-env short-circuits when env unchanged (verified activate script
    snapshot via context7).
- **Home Manager prezto module** (pinned source
  `modules/programs/zsh/plugins/prezto.nix:296-331, 538`): exposes
  `programs.zsh.prezto.syntaxHighlighting.styles` (attrsOf str) rendered as
  `zstyle ':prezto:module:syntax-highlighting' styles ...` — declarative,
  correct-ordering alternative to raw array assignment. Works identically on
  linux + darwin (same HM module).
- **HM zsh module** (`modules/programs/zsh/default.nix:619`):
  `enableCompletion` only emits compinit when prezto is NOT enabled — HM side
  is already correct; the duplicate comes from nix-darwin system level only.

## Affected Areas

- `darwin/system/` (new `zsh.nix`) — neutralize nix-darwin zsh defaults
- `hosts/mact2/default.nix` — flat import of new module (AGENTS.md convention)
- `darwin/home/shell.nix` — remove per-shell `mise install`/`reshim`
- `shared/shell-aliases.nix` — migrate ZSH_HIGHLIGHT_STYLES block off initContent
- `linux/home/shell.nix` + `darwin/home/shell.nix` — receive declarative styles
- Out of scope but noted: `linux/system/base/zsh.nix` sets NixOS-level
  `enableCompletion = true`; Linux hosts may have a smaller double-compinit
  too (unmeasured).

## Approaches

1. **Neutralize nix-darwin defaults at system level** — new tiny module
   `darwin/system/zsh.nix` setting `programs.zsh.promptInit = ""`,
   `programs.zsh.enableCompletion = false`, `programs.zsh.enableBashCompletion
   = false`; flat-imported in `hosts/mact2/default.nix`.
   - Pros: keeps `/etc/zshenv`, brew shellenv injection point, history setup;
     minimal diff; follows flat-import convention.
   - Cons: none identified; options are plain overrides (no mkForce needed —
     nothing else sets them at system level).
   - Effort: Low. Savings: ~0.6s (measured via NOSYSZSHRC bisect).

2. **Disable `programs.zsh.enable` entirely** — remove /etc/zshrc generation.
   - Pros: most aggressive cut.
   - Cons: loses /etc/zshenv (NIX_PATH/nix profile env) and the documented
     injection point nix-homebrew relies on; Apple stock files may resurface;
     riskier.
   - Effort: Medium. Rejected.

3. **Trim mise initContent** — keep `eval "$(mise activate zsh)"` (required
   for `[env]` support), delete per-shell `mise install` + `mise reshim`.
   Optionally wrap activate eval in mtime-keyed cache file.
   - Pros: aligns with official mise guidance; no functional loss (reshim is
     automatic on tool changes; `mise install` belongs to explicit workflow).
   - Cons: users who relied on implicit auto-install lose it (acceptable;
     can alias if needed).
   - Effort: Low. Savings: ~0.15-0.25s measured-equivalent; up to ~0.4s with
     eval caching.

4. **Fix styles via `prezto.syntaxHighlighting.styles`** — move palette-driven
   attrs into the HM option in both platform shell modules; delete raw
   assignments from shared/shell-aliases.nix initContent.
   - Pros: declarative, ordering-guaranteed, fixes error on all hosts.
   - Cons: requires threading colorScheme palette into the attrs (trivial).
   - Effort: Low. Savings: removes error noise; correctness fix.

## Recommendation

Apply 1 + 3 + 4. Expected result: ~1.3s → ~0.15-0.25s steady-state
(measured components sum: 0.09s base + ~50-100ms mise activate + margin).
Keep approach 2 out. Consider Linux double-compinit as follow-up change
after measuring a Linux host.

## Risks

- Losing brew shellenv if wrong option is disabled — mitigated by keeping
  `programs.zsh.enable = true` and only blanking prompt/completion options;
  verify `brew` still resolves after switch.
- Ghostty shell integration expects certain hooks; unaffected (it sources its
  own integration script in HM .zshrc).
- `mise install` removal changes behavior for uninstalled tools (auto-install
  on shell open disappears) — intentional; document in commit message.
- Styles migration must preserve exact palette mapping or colors shift.

## Ready for Proposal

Yes — recommend proposal covering approaches 1, 3, 4 with host scope =
mact2 (system-level change) + shared HM fix affecting darwin & linux hosts.
