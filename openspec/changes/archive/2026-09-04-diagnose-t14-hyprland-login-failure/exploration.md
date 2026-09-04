## Exploration: t14 Hyprland login failure after greetd authentication

### Current State
Observed facts:
- Current upstream guidance says `programs.hyprland.withUWSM = true` generates a UWSM-managed desktop entry and that Home Manager's Hyprland systemd integration should be disabled when UWSM manages the session.
- GitHub prior art includes a 2026 Hyprland report where the Home Manager-generated `systemctl --user stop hyprland-session.target && start hyprland-session.target` kills a UWSM-managed compositor through systemd target binding. Treat this as relevant prior art, not proof for t14.
- `flake.lock` pins `glats/omarchy-nix` at `f33d8813f6451baa042f41dcef543a27fa7dac2c`.
- At that omarchy-nix revision, `modules/nixos/hyprland.nix` enables `programs.hyprland.withUWSM = lib.mkDefault true` and installs a custom `hyprland-uwsm.desktop` when seamless boot is enabled.
- At that omarchy-nix revision, `modules/home-manager/hyprland.nix` enables Home Manager Hyprland but does not disable `wayland.windowManager.hyprland.systemd.enable`.
- At that omarchy-nix revision, `modules/home-manager/hyprland/autostart.nix` starts apps through `uwsm-app`, restarts `waybar`, and starts `hyprpolkitagent`.
- At that omarchy-nix revision, `modules/nixos/system.nix` enables `programs.uwsm.enable = true`; for `tuigreet`, it runs `tuigreet --cmd '${pkgs.uwsm}/bin/uwsm start hyprland-uwsm.desktop'`.
- Local `hosts/t14/omarchy-config.nix` currently sets `omarchy.greeter.type = "tuigreet"` as a temporary rescue path.
- Local `hosts/t14/default.nix` currently creates an empty `/etc/greetd/hyprland.conf` only when `greeter.type == "tuigreet"`, documented as a placeholder for an omarchy-nix eval issue when regreet is off.
- Local `hosts/t14/home/omarchy.nix` currently force-overrides `wayland.windowManager.hyprland.systemd.extraCommands` to run `uwsm finalize ...` and then stop/start `hyprland-session.target`.

Hypotheses to verify with runtime logs:
- Strongest hypothesis: UWSM and Home Manager Hyprland systemd integration are both active, and the HM `hyprland-session.target` stop/start path terminates or destabilizes the UWSM session after authentication.
- Secondary hypothesis: `tuigreet` is only an isolation layer; authentication works, but the selected session or session target graph is wrong after auth.
- Weaker hypothesis: the greeter placeholder or regreet-specific config is causing the post-auth failure. Local code suggests these are not in the user session path when `tuigreet` is active.

Missing runtime evidence:
- Fresh `journalctl --user -b` around the failed login showing whether Hyprland receives SIGTERM after the HM-generated stop/start command.
- Fresh `journalctl -b -u greetd` showing the exact session command selected by `tuigreet`.
- `systemctl --user status wayland-wm@*.service wayland-session@*.target graphical-session.target hyprland-session.target` immediately after a failed login attempt.
- Generated `~/.config/hypr/hyprland.conf` first `exec-once` line from the deployed generation.

### Affected Areas
- `hosts/t14/omarchy-config.nix` — currently selects the temporary `tuigreet` path and should not be treated as final UX.
- `hosts/t14/default.nix` — contains the temporary `/etc/greetd/hyprland.conf` placeholder used only because tuigreet disables regreet.
- `hosts/t14/home/omarchy.nix` — contains the local rescue override for Home Manager Hyprland `systemd.extraCommands`; likely the shortest reversible experiment is here.
- `flake.lock` — pins the exact omarchy-nix revision being tested: `f33d8813f6451baa042f41dcef543a27fa7dac2c`.
- `glats/omarchy-nix:modules/nixos/hyprland.nix` — enables UWSM for Hyprland and owns the generated system-level session behavior.
- `glats/omarchy-nix:modules/home-manager/hyprland.nix` — enables HM Hyprland but currently leaves HM systemd integration at its default.
- `glats/omarchy-nix:modules/home-manager/hyprland/autostart.nix` — assumes a UWSM-aware session by using `uwsm-app` and systemd user services.
- `glats/omarchy-nix:modules/nixos/system.nix` — wires greetd/tuigreet/regreet and `programs.uwsm.enable`.

### Approaches
1. **Runtime proof only** — collect the missing journals and generated config before editing.
   - Pros: Zero code; confirms whether the exact target-stop failure is happening.
   - Cons: Needs a failed login attempt and shell/SSH access.
   - Effort: Low

2. **Minimal local separator** — remove the local `systemd.extraCommands` rescue override and force `wayland.windowManager.hyprland.systemd.enable = false` only on t14.
   - Pros: Shortest reversible config experiment; directly matches current Hyprland/NixOS guidance; avoids more stop/start target manipulation.
   - Cons: Local-only; if it works, the cleaner final fix likely belongs in omarchy-nix.
   - Effort: Low

3. **Upstream omarchy-nix alignment** — disable HM Hyprland systemd integration in omarchy-nix whenever its NixOS module uses UWSM, then bump the pin in `.nixos`.
   - Pros: Clean root-layer fix; removes the need for local rescue commands.
   - Cons: Touches a separate repo and requires pin update validation.
   - Effort: Medium

4. **Greeter swap/regreet work** — continue changing greeter implementation or `/etc/greetd/hyprland.conf`.
   - Pros: Could matter if logs prove the session command never reaches UWSM.
   - Cons: Local facts currently point after authentication, so this is likely not the shortest path.
   - Effort: Medium

### Recommendation
Use the ponytail path: first prove the target-stop hypothesis from logs if possible; if logs are unavailable, the shortest reversible next experiment is Approach 2: disable Home Manager Hyprland systemd integration on t14 and remove the local `systemd.extraCommands` rescue override. If that fixes login, promote the same behavior to omarchy-nix and keep `tuigreet` only until the user session is stable; restore/regreet separately later.

### Risks
- Disabling HM Hyprland systemd integration may stop `hyprland-session.target`-bound services from starting unless UWSM's `graphical-session.target` path covers them as expected.
- The local `uwsm finalize` override may be hiding part of the real generated behavior; remove it only as a controlled separator.
- Runtime logs may show a different root cause, especially GPU/aquamarine startup failure or session selection mismatch.
- Fixing login and restoring regreet are separate changes; combining them risks another poor broad fix.

### Ready for Proposal
Yes — but only for a narrow diagnosis/proof proposal. Tell the user the current best candidate is not another greeter tweak: it is to verify and then remove the UWSM + Home Manager systemd-session conflict with the smallest reversible t14-only experiment before promoting anything upstream.
