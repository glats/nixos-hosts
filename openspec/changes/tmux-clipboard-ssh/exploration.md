## Exploration: tmux-clipboard-ssh

### Current State

**Tmux configuration layout** (three files, layered):

- `shared/tmux.nix` — common base. Sets `set -g allow-passthrough on` (line 14) plus base16 theme, vi mode, mouse on, history, status bar. This is the single source of truth for platform-shared tmux options. `allow-passthrough on` is the gateway that lets OSC 52 escape sequences flow from inside tmux out to the outside terminal — it is already enabled on all hosts.
- `home-linux/tmux.nix` — Linux overlay. `escapeTime = 0`, nixpkgs plugins list (`resurrect`, `sessionist`, `yank`, `vim-tmux-navigator`), and five `copy-pipe-and-cancel` bindings that pipe to `xclip -i -selection clipboard` (lines 51–55). Both `copy-mode` and `copy-mode-vi` get `y` and `Enter` and `MouseDragEnd1Pane` piped to the local xclip. **There is no `set -s set-clipboard` here.**
- `home-darwin/tmux.nix` — Darwin overlay. `escapeTime = 10`, TPM-based plugins (cloned by HM activation), `set -s set-clipboard on` (line 62), and `copy-pipe-and-cancel "pbcopy"` bindings on the same `y` / `Enter` / `MouseDragEnd1Pane` keys (lines 64–68).

**Local vs SSH behaviour today**:

- *Local on rog/thinkcentre (X11)* — tmux runs inside the user's MATE session. `xclip` writes to the local X11 `clipboard` selection. The user's local ghostty reads from the same selection. Works.
- *Local on t14 (Hyprland/Wayland)* — tmux runs in ghostty on a Wayland session. The current Linux bindings still pipe to `xclip`. xclip on Wayland requires XWayland to be running and `DISPLAY` to be set; on a pure-Wayland ghostty window this is not guaranteed. `wl-clipboard` is not in the package set anywhere in the repo (verified: no matches for `wl-copy`, `wl-paste`, `wl-clipboard` in any `.nix` file). **The current Linux tmux config is already at risk on t14 even before considering SSH.**
- *Local on mact2 (macOS)* — `pbcopy` writes to the macOS pasteboard inside the local user session. Works.
- *rog → mact2 over SSH (the reported failure)* — user is on rog, ghostty in rog. SSH into mact2, run tmux, hit `y` in copy-mode. The binding runs `pbcopy` **on mact2**, which writes to **mact2's** local pasteboard. The text never leaves mact2; the local rog ghostty clipboard is empty. Same failure in reverse (mact2 → rog: `xclip` on rog has no `$DISPLAY` because the SSH session is non-graphical, so xclip exits with `Error: Can't open display:`).
- *rog → thinkcentre over SSH* — same as above. `xclip` on thinkcentre over SSH from rog fails to open the display.
- *t14 → anywhere* — same failure mode; plus the local case is already flaky on t14 itself.

**Terminal emulator**: `ghostty` everywhere (rog/thinkcentre via `home-linux/shared-modules.nix` → `home-linux/ghostty.nix`; t14 via `hosts/t14/home/ghostty.nix` → same shared `home-linux/ghostty.nix`; mact2 via `home-darwin/ghostty.nix`). Ghostty 1.0+ supports OSC 52 by default (`clipboard-write = allow` is the default; `clipboard-read = ask` is the default). Neither ghostty config currently sets `clipboard-write` or `clipboard-read` explicitly, so the defaults apply. Kitty is also enabled as a fallback terminal on Linux hosts (`home-linux/kitty.nix`) — kitty also supports OSC 52 by default but exposes a `clipboard_control` setting; the current kitty config does not set it.

**OSC 52 status in current config**: tmux-side passthrough is enabled (`allow-passthrough on` in `shared/tmux.nix`). Terminal-side OSC 52 is enabled by Ghostty defaults. What is **missing** is the trigger: no `set -s set-clipboard on` on Linux (Darwin already has it), and every Linux copy-mode binding explicitly pipes to `xclip` instead of letting tmux emit OSC 52. On Darwin, the explicit `pbcopy` pipe overrides the `set-clipboard on` for `y`/`Enter`/`mouse`, so OSC 52 is never actually emitted on the hot keys either.

**SSH configuration** (`home-linux/ssh.nix`, `home-darwin/ssh.nix`): each LAN host has an entry with `User`, `IdentityFile`, `IdentitiesOnly`, and a `SetEnv.TERM = "xterm-256color"`. No `ForwardX11`, no `ForwardAgent`, no `RemoteForward`. The SSH server module (`modules/networking/openssh.nix`) is the standard NixOS sshd with password+pubkey and `PermitRootLogin = "no"`. **Nothing in the SSH config interferes with OSC 52 passthrough; nothing in the SSH config helps with it either.** tmux's `allow-passthrough on` plus the local terminal's default OSC 52 support is enough; no SSH-side change is required.

**User identity** on `mact2` is `jcuzmar`, on all NixOS hosts is `glats`. This matters only for SSH key lookup (`IdentityFile = ~/.ssh/mact2` on Linux; the user only SSHes from rog/thinkcentre/t14 to mact2). Not a clipboard concern.

**Tmux-yank plugin**: included in `pkgs.tmuxPlugins` on Linux (line 40 of `home-linux/tmux.nix`). It provides `prefix-y` (copy command line) and the standard `y` / `Enter` in copy-mode by default — but the explicit `copy-pipe-and-cancel "xclip ..."` bindings in `extraConfig` take precedence for the same keys (the order in the merged tmux.conf is `shared base` → `linux xclip bindings`, both inside the `lib.mkForce` block, so xclip wins). tmux-yank's own autodetected copy command on Linux is `xclip` or `xsel`; on macOS it is `pbcopy`. tmux-yank does **not** natively emit OSC 52; it requires either a custom `@override_copy_command` (a shell snippet) or removal of the explicit pipe bindings in favor of tmux's `set-clipboard` mechanism.

**Nixpkgs tmux-yank pin**: `pkgs.tmux-plugins/default.nix` pins `yank` at `unstable-2023-07-19` (rev `acfd36e4fcba99f8310a7dfb432111c242fe7392`). Newer behavior (e.g. tmux 3.2+ `copy-command` option) is available because the underlying tmux in nixpkgs-unstable is 3.4+.

### Affected Areas

- `home-linux/tmux.nix` — needs to drop the five `xclip` `copy-pipe-and-cancel` bindings (or replace them with no-op / OSC 52 emission) and add `set -s set-clipboard on`. Currently the only file that hard-codes the broken-over-SSH behaviour.
- `home-darwin/tmux.nix` — has the same pattern: `pbcopy` `copy-pipe-and-cancel` overrides the existing `set-clipboard on` for `y`/`Enter`/`mouse`. Needs the same treatment for SSH symmetry (mact2 → rog SSH case).
- `shared/tmux.nix` — candidate to host `set -s set-clipboard on` once both platforms agree, removing the need to duplicate it. Today it only carries `allow-passthrough on`. Becomes the natural single source of truth if both files converge on the OSC 52 path.
- `home-linux/ghostty.nix` — needs explicit `clipboard-write = allow` (it is the Ghostty 1.x default, but pinning it makes the SSH clipboard contract explicit and reviewable). `clipboard-read` should stay at default `ask` for security; do not change.
- `home-darwin/ghostty.nix` — same: needs explicit `clipboard-write = allow` (currently writes a raw ghostty config file without any clipboard setting).
- `home-linux/kitty.nix` — secondary terminal. If kitty is used as the SSH client terminal, kitty's `clipboard_control = write` is the equivalent knob. Worth a small note in the spec that kitty is supported; the current config does not set it.
- `modules/base/profiles/base.nix` — `xclip` is added here. If the Linux tmux config no longer uses xclip (because OSC 52 takes over), `xclip` becomes a candidate for removal. The repo also pins `copyq` and `gpaste` here; both are local clipboard managers, not relevant to tmux. **Risk**: t14 may need `wl-clipboard` for any non-tmux local clipboard use; not added today.
- `modules/networking/openssh.nix` — no behavioural change required. Worth confirming in the proposal phase that `allow-passthrough` is preserved by `sshd_config` defaults (it is: the NixOS `services.openssh` does not touch the `AcceptEnv`/escape passthrough behaviour).
- `home-linux/ssh.nix` / `home-darwin/ssh.nix` — no change. The current per-host entries do not need X11 forwarding for OSC 52 to work; OSC 52 travels in-band in the terminal byte stream and does not require `ForwardX11`.

### Approaches

1. **Pure OSC 52 via tmux `set-clipboard`** — drop the explicit `copy-pipe-and-cancel "xclip"` (Linux) and `"pbcopy"` (Darwin) bindings. Set `set -s set-clipboard on` in `shared/tmux.nix` (or in each platform file if we keep the platform split). Rely on tmux 3.2+ behavior: when no `copy-command` is set and the user triggers the default `copy-pipe` action, tmux emits an OSC 52 sequence with the selection. Local ghostty/kitty receives it and writes to the local clipboard. Works both locally and over SSH because the OSC 52 sequence rides the terminal byte stream.
   - Pros: cleanest; one mechanism; works for local + SSH + cross-OS in either direction; removes the need for xclip in the tmux copy path; matches what the tmux wiki and ghostty docs recommend; removes the t14 local flakiness as a bonus.
   - Cons: requires Ghostty 1.0+ (this repo already pins ghostty via flake input, so this is satisfied). Drops the `xclip` runtime dependency for tmux, but xclip may still be needed by other apps (neovim, scripts) — keep it in `modules/base/profiles/base.nix`.
   - Effort: **Low**. Touch `shared/tmux.nix` (add `set -s set-clipboard on`), `home-linux/tmux.nix` (delete the five xclip bindings), `home-darwin/tmux.nix` (delete the five pbcopy bindings or leave pbcopy in place and accept that local-Darwin copy still works but SSH-from-Darwin still fails — but the user wants SSH to work, so delete).

2. **Hybrid: keep `copy-pipe` for local, add OSC 52 for SSH** — keep `xclip`/`pbcopy` pipe commands but also set `set -s set-clipboard on` so tmux emits OSC 52 in parallel. tmux wiki explicitly warns this combination can double-emit and conflict. Worse: tmux's `set-clipboard` only fires for the *default* `copy-pipe` (no-arg) — explicit pipe commands suppress it. So this approach does not actually solve the SSH case.
   - Pros: minimal config change.
   - Cons: does not actually fix SSH; conflicts documented in the tmux wiki; double-write; confusing for future readers.
   - Effort: **Low** but **wrong**. Reject.

3. **tmux-yank `@override_copy_command` with an OSC 52 emitter** — write a tiny shell wrapper (e.g. `pkgs.writeShellScript "osc52-copy" 'printf "\\033]52;c;$(base64 -w0)\\007"'`) and tell tmux-yank to use it via `set -g @override_copy_command`. Keep the xclip/pbcopy pipe commands as a fallback for tmux-yank's `prefix-y` path. OSC 52 escapes flow through the local terminal.
   - Pros: scoped to tmux-yank bindings; leaves the explicit xclip/pbcopy pipes alone (so existing muscle memory does not break); uses a mechanism the user can read and reason about.
   - Cons: more moving parts than Approach 1; requires adding a derivation to the flake (small); does not address the case where a user uses the default tmux `y` binding (which is what the current xclip bindings override); partial coverage.
   - Effort: **Medium**. Plus the OSC 52 emitter wrapper.

4. **Status quo + `mosh`** — recommend the user switch from SSH to mosh for cross-host work, since mosh has its own terminal-passthrough channel.
   - Pros: no config change.
   - Cons: does not address the user's stated goal (SSH clipboard), contradicts the requirement; the user is on SSH today.
   - Effort: **None for the repo, but fails the user goal.** Reject.

### Recommendation

Use **Approach 1** (pure OSC 52 via `set-clipboard on`) as the primary path. The repo is already 80% of the way there: `allow-passthrough on` is set, ghostty supports OSC 52 by default, and Darwin already has `set -s set-clipboard on`. The only missing piece is mirroring `set-clipboard on` to Linux and removing the explicit `xclip`/`pbcopy` pipe commands that suppress OSC 52 on the hot keys.

Concrete recipe for the proposal phase:

- Add `set -s set-clipboard on` to `shared/tmux.nix` extraConfig (single source of truth, matches `allow-passthrough on`).
- Delete the five `copy-pipe-and-cancel "xclip ..."` lines from `home-linux/tmux.nix`. tmux 3.2+ then emits OSC 52 on the default `copy-pipe` action.
- Delete the five `copy-pipe-and-cancel "pbcopy"` lines from `home-darwin/tmux.nix` for SSH symmetry. The existing `set-clipboard on` then takes over.
- Pin `clipboard-write = allow` explicitly in `home-linux/ghostty.nix` and `home-darwin/ghostty.nix` so the contract is reviewable. Leave `clipboard-read` at the default `ask` (security: do not silently allow remote apps to read the local clipboard).
- Add `clipboard_control = write` to `home-linux/kitty.nix` for parity (only if kitty is used as the SSH client terminal in practice — confirm with the user during proposal).
- Keep `pkgs.xclip` in `modules/base/profiles/base.nix` because neovim and other tools still use it. Do not remove.
- No change to `modules/networking/openssh.nix`, `home-linux/ssh.nix`, or `home-darwin/ssh.nix`.

**Optional hardening (proposal decides)**:

- Add `wl-clipboard` to `modules/base/profiles/base.nix` for t14 so non-tmux local clipboard use on Wayland works. Out of scope for the user's stated tmux problem but a one-line win.
- Consider adding `set -g set-clipboard on` semantics plus an OSC 52 emitter in the rare case a user is on a terminal that does not support OSC 52 reads (e.g. an embedded serial console). Out of scope; n/a here.

### Risks

- **Behaviour change at the hot key**: today `prefix-y` and copy-mode `y`/`Enter` on Linux pipe to xclip. After this change they emit OSC 52. Locally the behaviour is identical (xclip wrote to the same X11 selection that ghostty reads; OSC 52 now tells ghostty to put the same data on the same selection). On SSH they go from "broken silently" to "working via terminal passthrough". This is the desired outcome but reviewers may flag it as a user-visible change to muscle memory; the change is invisible to the user.
- **`xclip` no longer required by tmux**: xclip stays in the base package set for neovim/scripts, but if any user script depends on `xclip` being called by tmux specifically (very unlikely), that script will break. Grep the repo first.
- **Ghostty version sensitivity**: OSC 52 write is the default in Ghostty 1.0+. The flake input is `github:ghostty-org/ghostty` (no version pin in `flake.nix` line 108). If a future ghostty bump flips the default to `deny`, the explicit `clipboard-write = allow` in the ghostty config files prevents regression.
- **Kitty not on the SSH path today**: ghostty is the dominant terminal. The user has not said which terminal they run in for SSH sessions. The exploration assumes ghostty; if the user SSHes from kitty, `clipboard_control = write` must also be set in `home-linux/kitty.nix`. Confirm with the user during proposal.
- **t14 (Hyprland) pre-existing local flakiness**: t14 is not in the user's stated flow (rog ↔ mact2), but the current xclip-based Linux tmux config is already unreliable on t14. The OSC 52 fix happens to also fix t14. Worth calling out in the proposal as a side benefit, not as the primary goal.
- **No `wl-clipboard` for t14**: t14 has no `wl-copy`/`wl-paste` available. Any non-tmux local clipboard use on t14 (e.g. `wl-copy < file` in a script) currently requires XWayland xclip. Not addressed by this change. Out of scope per the user's request.
- **400-line review budget is trivially safe**: the change touches ≤6 lines of Nix across ≤5 files, all `.nix`. review_budget = 3 from the preflight applies to a delivery strategy. No chained PRs required. Single PR is sufficient.
- **Darwin SSH symmetry**: removing `pbcopy` pipe commands on Darwin makes the SSH-from-mact2 case (mact2 → rog) work, but it also means the local copy on mact2 now goes via OSC 52 → ghostty-on-mact2 → mact2 pasteboard. On macOS Ghostty, the OSC 52 path is the recommended one and is exercised by the `reattach-to-user-namespace` package in `home-darwin/tmux.nix` already (the package is currently a no-op for OSC 52; it is there for legacy `pbcopy` reasons). No regression expected.

### Ready for Proposal

Yes — the proposal should frame this as a tmux config consolidation that *adds* SSH clipboard support by switching the Linux copy pipeline from `xclip` to OSC 52 and unifying Linux + Darwin on a single `set -s set-clipboard on` path. Workstreams:

1. **Config change**: add `set -s set-clipboard on` to `shared/tmux.nix`; delete the five `xclip` `copy-pipe-and-cancel` bindings from `home-linux/tmux.nix`; delete the five `pbcopy` `copy-pipe-and-cancel` bindings from `home-darwin/tmux.nix`.
2. **Terminal hardening**: explicit `clipboard-write = allow` in `home-linux/ghostty.nix` and `home-darwin/ghostty.nix`; `clipboard_control = write` in `home-linux/kitty.nix` (only if the user confirms kitty is in the SSH path).
3. **Verification**: `nix flake check --no-build`; manual test on rog (local), rog → mact2 (SSH), mact2 → rog (SSH), thinkcentre (local + via SSH from rog). Verify both copy-from-tmux and copy-from-mouse-drag work. Verify neovim `*`/`+` registers still work (they should — neovim uses its own OSC 52 provider, independent of tmux).
4. **Optional side quest**: add `wl-clipboard` to `modules/base/profiles/base.nix` for t14. Tag as out-of-scope-by-default; include as a follow-up if the user wants it.

The proposal should also confirm with the user: which terminal they use to SSH from (ghostty or kitty), and whether they want t14 hardened in the same change.

---

## Open Question Findings (follow-up exploration)

### Question 1: MATE Terminal OSC 52 support

**Answer: NO — MATE Terminal cannot receive OSC 52 with the current nixpkgs.**

**Repo evidence**:
- `home-linux/mate.nix` (line 77, 254): `pkgs.mate-terminal` is the user's default terminal on rog/thinkcentre (set as `org/mate/desktop/applications/terminal/exec` and as a `xdg.dataFile` desktop entry).
- `home-linux/mate.nix` dconf block: `org/mate/terminal/profiles/default` only sets colors/font, no OSC-related key. There is no `allow-unsafe-osc52` (or any `osc52` key) in the MATE Terminal gsettings schema.

**nixpkgs evidence**:
- `pkgs.mate-terminal/1.28.3` in nixpkgs unstable. Built on VTE.
- `pkgs.vte/0.82.3` (current unstable, 0.85.0 in development) in nixpkgs.

**VTE OSC 52 implementation status (as of master, 2026)**:
- The VTE upstream **deliberately refuses** OSC 52. Issue `GNOME/vte#2495` (filed 2018) is still the canonical tracker; the VTE maintainer has repeatedly rejected the feature, citing security/privacy concerns (see `gnunn1/tilix#2198` for the VTE-maintainer quote).
- `vteseq.cc` master (verified at gitlab.gnome.org/GNOME/vte/-/raw/master/src/vteseq.cc): the OSC handler at line ~8036 defines `VTE_OSC_XTERM_SET_XSELECTION` as a case label, but the handler falls through to `default: break;`. **It is a no-op.**
- The user's premise "VTE supports OSC 52 since 0.52+" is **incorrect**. VTE 0.52 added the generic OSC *parser*; the OSC 52 *handler* has never been implemented.
- VTE also has a different `case 52` (WYCOLOR cursor color) in a CSI context — that is unrelated to xterm's clipboard OSC 52.

**MATE Terminal gsettings** (`org.mate.terminal`):
- The schema has: `profile-list`, `default-profile`, `use-menu-accelerators`, `active-encodings`, `confirm-window-close`, plus per-profile `font`, `palette`, `background-color`, etc.
- **No `allow-unsafe-osc52`, no `osc52`, no clipboard-related key of any kind.**
- MATE Terminal is a thin VTE wrapper; it cannot expose a config that VTE does not implement.

**NixOS option search**:
- `services.xserver.desktopManager.mate` has only 5 options: `debug`, `enable`, `enableWaylandSession`, `extraCajaExtensions`, `extraPanelApplets`. **No clipboard/OSC option.**
- `programs.bash.vteIntegration` and `programs.zsh.vteIntegration` exist but are unrelated (they emit a shell integration marker, not OSC 52).

**Conclusion for the design**:
- MATE Terminal on rog/thinkcentre **cannot** be made to receive OSC 52 with the current VTE version. The only options are (a) use a different terminal (ghostty, kitty, foot, alacritty, wezterm) for SSH client sessions, or (b) wait for upstream VTE to merge OSC 52 (no sign of that as of 2026).
- The user's rog/thinkcentre already have ghostty installed (`home-linux/ghostty.nix` declares ghostty for all Linux hosts, including rog/thinkcentre via `home-linux/shared-modules.nix` → `flake.nix` `linuxHomeModules`). The user's stated SSH flow (rog → mact2) is ghostty → mact2's tmux, which works with the OSC 52 path.
- **Risk: any SSH session initiated from a MATE Terminal window on rog/thinkcentre will silently fail to sync clipboard via OSC 52.** Worth a one-line note in the design; not a blocker for the user's stated flow.

### Question 2: Kitty as SSH client terminal

**Repo evidence**:
- `home-linux/kitty.nix` (single source of truth for kitty on all Linux hosts). Current settings: `background_opacity`, `font`, `background`, palette colors. **No `clipboard_control` key set.**
- `programs.kitty.enable = true` for all Linux hosts.

**kitty `clipboard_control` default (current upstream, verified)**:
- The current kitty default (per `kitty/options/types.py` `f13c8cd4` and the published `kitty.conf(5)` man page) is:
  ```
  clipboard_control write-clipboard write-primary read-clipboard-ask read-primary-ask
  ```
- The user's claim of default `write-clipboard write-primary` matches an *older* default (pre-`read-*-ask` introduction). Modern kitty (released 2018+; verified on 0.47.4 in 2026) also enables `read-clipboard-ask` and `read-primary-ask` by default.
- OSC 52 **writes** (the direction this change cares about) are enabled by default. `read-clipboard-ask` only affects remote → local clipboard *reads*, which is the security-sensitive direction we explicitly want to keep gated.
- The phrase `clipboard_control = write` is not a valid kitty setting value. Kitty's `clipboard_control` is a space-separated set of tokens from: `write-clipboard`, `read-clipboard`, `write-primary`, `read-primary`, `read-clipboard-ask`, `read-primary-ask`, `no-append`. A single word `write` would be parsed as an unknown token and rejected (or accepted as garbage).

**Conclusion for the design**:
- **No explicit `clipboard_control` line is needed in `home-linux/kitty.nix`.** The default already permits OSC 52 writes. Adding `clipboard_control = write-clipboard write-primary` would actually *narrow* the default (drop the read-asks), and adding `clipboard_control = write-clipboard` would disable OSC 52 writes to the primary selection.
- Recommendation: leave kitty config alone for this change. If a future change wants to pin the contract, the correct line is `clipboard_control = write-clipboard write-primary read-clipboard-ask read-primary-ask` (i.e. pin the default), not `= write`.
- The exploration's earlier `clipboard_control = write` suggestion is **wrong**; it would break OSC 52 primary writes and is not a valid token anyway.

### Question 3: tmux-yank `prefix-y` behavior

**Repo evidence**:
- `home-linux/tmux.nix` line 37-42: `plugins = lib.mkForce (with pkgs.tmuxPlugins; [ resurrect sessionist yank vim-tmux-navigator ]);` — yank plugin is loaded via nixpkgs on Linux.
- `home-darwin/tmux.nix` line 71-75: TPM plugin list includes `set -g @plugin 'tmux-plugins/tmux-yank'` — yank is loaded via TPM on Darwin.
- `home-linux/tmux.nix` lines 51-55: five `bind -T copy-mode[-vi] ... copy-pipe-and-cancel "xclip -i -selection clipboard"` bindings for `y`, `Enter`, and `MouseDragEnd1Pane`.

**tmux-yank source behavior (verified at github.com/tmux-plugins/tmux-yank master)**:
- The plugin's `yank.tmux` calls `set_copy_mode_bindings` which (for tmux ≥ 2.4) registers:
  ```
  bind -T copy-mode-vi y    send -X copy-pipe-and-cancel "$copy_command"
  bind -T copy-mode    y    send -X copy-pipe-and-cancel "$copy_command"
  bind -T copy-mode-vi Enter send -X copy-pipe-and-cancel "$copy_command"
  ...
  ```
  where `$copy_command` is the output of `clipboard_copy_command()` (an autodetected xclip/pbcopy/wl-copy/...).
- tmux-yank **binds `y` and `Enter` in copy-mode with explicit `copy-pipe-and-cancel`**, which **suppresses** tmux's `set-clipboard on` mechanism. Even if we add `set -s set-clipboard on` to `shared/tmux.nix`, **the `y` key in copy-mode will still pipe to xclip/pbcopy** (not OSC 52), because tmux-yank's bind wins for the same key.
- This is true for **both** the nixpkgs path (Linux, `pkgs.tmuxPlugins.yank`) and the TPM path (Darwin, `@plugin 'tmux-plugins/tmux-yank'`).
- For the `prefix-y` normal-mode binding: tmux-yank registers `bind y run-shell -b "$SCRIPTS_DIR/copy_line.sh"`. This is a shell pipeline, not a `copy-pipe-and-cancel`, so it bypasses `set-clipboard` entirely. `copy_line.sh` itself uses `clipboard_copy_command` (xclip/pbcopy).

**The `@override_copy_command` option**:
- tmux-yank exposes `set -g @override_copy_command "your-command-here"`. If set, this *replaces* the autodetected `clipboard_copy_command` for all of tmux-yank's bindings.
- A typical OSC 52 emitter would be: `printf '\e]52;c;%s\a' "$(base64 | tr -d '\n')"` written to `/dev/tty`.
- `@custom_copy_command` is only used as a *fallback* when no known clipboard program is found; it would be ignored on rog/thinkcentre (xclip exists) and on mact2 (pbcopy exists).

**Conclusion for the design**:
- **Removing the explicit `xclip`/`pbcopy` `copy-pipe-and-cancel` bindings in `home-linux/tmux.nix` and `home-darwin/tmux.nix` is necessary but not sufficient for OSC 52 to work on the `y` hot key.** tmux-yank's own bindings on the same keys will still pipe to xclip/pbcopy, not OSC 52.
- To get OSC 52 for `y` in copy-mode AND `prefix-y` in normal mode, we need to either:
  - **(a) Set `@override_copy_command`** in shared tmux config to a shell snippet that emits OSC 52 (one configuration, works for both `y` and `prefix-y`). This is the cleanest path; it overrides tmux-yank's autodetection for all its bindings. Effort: low. Risk: small (need a portable OSC 52 emitter).
  - **(b) Disable tmux-yank's copy-mode bindings** (e.g. by removing the `yank` plugin from the nixpkgs set on Linux, or by adding tmux-yank's `@yank_with_mouse off` plus a fresh binding for `y` that uses `copy-pipe` with no command). tmux's default `y` binding is `copy-pipe -s send-keys -X copy-pipe-and-cancel ""` — i.e. emits OSC 52 if `set-clipboard on` is set. This is more invasive and removes tmux-yank features the user may want. Effort: medium.
  - **(c) Use tmux-yank's `@custom_copy_command` as a fallback** — but it would not be picked up because xclip/pbcopy exist. **Reject.**
- **Recommended path: (a) — add `@override_copy_command` in `shared/tmux.nix`**. Effort: low. The OSC 52 emitter needs to be a portable shell snippet (bash). Sample: `printf '\033]52;c;%s\007' "$(base64 | tr -d '\n')" > /dev/tty`. Verify against tmux escape semantics: tmux 3.2+ `set-clipboard` produces `\e]52;c;<base64>\e\\` (ST terminator). The shell emitter must match. **The `@override_copy_command` option is read by tmux-yank at bind time, so the `set -g @override_copy_command` line must come before tmux-yank is sourced.** That means it must be in `shared/tmux.nix` *before* the `plugins` list, or in the platform file *before* the `run-shell` for TPM. nixpkgs plugins are sourced at config-eval time (not via `run-shell`), so order in the merged config matters; verify with `tmux info | grep -A1 yank` after the change.
- The exploration's "Approach 1" was correct on the *terminal-side* mechanics but missed the tmux-yank binding. The proposal must be updated: do not just drop the xclip/pbcopy bindings; also set `@override_copy_command` to make tmux-yank's `y` and `prefix-y` emit OSC 52.

### Question 4: NixOS option for MATE Terminal clipboard behavior

**Answer: NO such option exists.**

- Searched `services.xserver.desktopManager.mate` and `services.xserver.terminal.mate*` — only 5 options for MATE desktop: `debug`, `enable`, `enableWaylandSession`, `extraCajaExtensions`, `extraPanelApplets`. No clipboard-related option.
- The only MATE configuration path is `dconf.settings` (used in `home-linux/mate.nix`), which writes keys into the gsettings/dconf database. The MATE Terminal gsettings schema does not expose OSC 52.

### Question 5: VTE config option exposed in NixOS or Home Manager

**Answer: NO direct VTE config option.**

- `programs.bash.vteIntegration` (`programs.bash.vteIntegration = true;`) and `programs.zsh.vteIntegration` exist. These set `VTE_VERSION` env var and source `/etc/profile.d/vte*.sh` so that bash/zsh running inside a VTE-based terminal can preserve `$PWD` across new shells. **Unrelated to OSC 52.**
- No VTE option for OSC 52 enable/disable. As established in Q1, VTE does not implement OSC 52 at all, so there is nothing to enable.

### Summary table for the design phase

| Question | Answer | Implication for design |
|---|---|---|
| Q1: MATE Terminal OSC 52 | VTE 0.82.3 does NOT implement OSC 52; MATE Terminal inherits this. No gsettings key exists. | OSC 52 fails silently on any SSH session initiated from a MATE Terminal window. Mitigation: use ghostty/kitty (already installed) for SSH. Worth a one-line note in the proposal. |
| Q2: Kitty `clipboard_control` | Default in modern kitty is `write-clipboard write-primary read-clipboard-ask read-primary-ask`. OSC 52 writes are enabled by default. The exploration's suggested `clipboard_control = write` is invalid and would break primary writes. | **Do not add `clipboard_control` to `home-linux/kitty.nix`.** Leave kitty config alone. |
| Q3: tmux-yank `prefix-y` | tmux-yank binds `y` in copy-mode with explicit `copy-pipe-and-cancel` to xclip/pbcopy, which suppresses `set-clipboard on`. `prefix-y` runs `copy_line.sh` which uses the same xclip/pbcopy. To get OSC 52 from tmux-yank, set `@override_copy_command` to a shell OSC 52 emitter. | **Add `set -g @override_copy_command "..."` to `shared/tmux.nix` (before plugins) with a portable OSC 52 emitter.** Order matters: must come before the `yank` plugin binds. |
| Q4: NixOS MATE option | None. | n/a |
| Q5: NixOS VTE option | Only `programs.bash.vteIntegration` and `programs.zsh.vteIntegration` (cwd-preserving, unrelated). | n/a |

### Updated design implications (delta over proposal.md)

- **Add** `set -g @override_copy_command "..."` to `shared/tmux.nix` so tmux-yank's `y` and `prefix-y` emit OSC 52. The value is a shell command that reads from stdin and writes OSC 52 to `/dev/tty`. The exact emitter needs a design pass:
  - tmux's `set-clipboard` emits `ESC ] 5 2 ; c ; <base64> ESC \` (ST terminator, the `\\` form). This is the form that ghostty/kitty/alacritty/etc. recognize.
  - A bash emitter: `printf '\033]52;c;%s\007' "$(base64 | tr -d '\n')"` — but `\007` (BEL) terminator is also accepted by most terminals, and the OSC 52 spec lists BEL as the canonical terminator alongside ST. Belt and suspenders: `printf '\033]52;c;%s\033\\' "$(base64 | tr -d '\n')"`.
  - It MUST write to `/dev/tty`, not stdout, because the pipe is consumed by tmux.
- **Verify binding order**: `set -g @override_copy_command` must be set before the nixpkgs `yank` plugin is sourced (Linux) and before the TPM `run-shell` (Darwin). In `home-linux/tmux.nix`, the shared config is concatenated via `lib.mkForce` in `extraConfig` (line 48); the `set -g @override_copy_command` must appear in the `sharedExtraConfig` block, before the OS-specific extraConfig is concatenated. The current `shared/tmux.nix` already has `set -g allow-passthrough on` at the top of `extraConfig`; add `@override_copy_command` there.
- **MATE Terminal caveat**: add a note to the proposal's "Risks" table that OSC 52 silently fails when the SSH *client* terminal is MATE Terminal. Document that the user should SSH from ghostty/kitty/alacritty (already installed). No config change required to make MATE Terminal reject OSC 52; it just does.
- **Remove the `clipboard_control = write` line** from the proposal's `home-linux/kitty.nix` change. No kitty config change needed.
- **Affected file count grows from 6 to 7**: also touch `shared/tmux.nix` (already in scope) for the `@override_copy_command` line; the other file list stays the same. **Net diff: +4/-10** (was +3/-10): one extra line in `shared/tmux.nix`.

### Open follow-up for design

- Pick the exact `@override_copy_command` shell snippet and verify it round-trips through ghostty/kitty/alacritty. Candidates:
  1. Minimal: `printf '\033]52;c;%s\033\\' "$(base64 | tr -d '\n')" >/dev/tty`
  2. With portable `base64` (no `-w0` flag for BSD base64): `base64 | tr -d '\n'` works on both GNU and BSD because the `tr -d '\n'` strips any embedded newlines regardless of source.
  3. Belt-and-suspenders terminator: end with both BEL and ST. Most terminals accept either; OSC 52 spec says both are valid.
- Decide whether to keep the `pkgs.xclip` and `pkgs.pbcopy` packages in the host base set. Recommendation: keep both — xclip is still needed by neovim, rofi, and scripts; pbcopy stays as a Darwin helper for any program that calls it directly.

