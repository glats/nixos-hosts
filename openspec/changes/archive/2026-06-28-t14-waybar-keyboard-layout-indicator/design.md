# Design: t14 Waybar Keyboard Layout Indicator

## Technical Approach

Add a `custom/language` waybar module to the omarchy-nix waybar config that polls `kb-layout.sh` every 5 seconds for the current XKB layout and invokes `kb-toggle.sh` on click. The scripts already exist on t14 (deployed via `hosts/t14/home/default.nix:38-48`) and interact with Hyprland via `hyprctl`. The only code change is inserting the module into `config/waybar/config`; deployment to t14 happens through the existing `waybar.nix:10-13` recursive copy plus a flake lock bump.

## Architecture Decisions

### Decision: custom/language over native hyprland/language

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `custom/language` (shell exec) | 5s poll latency; proven script pattern; matches 5 other `custom/*` modules in this config | **Chosen** |
| `hyprland/language` (native IPC) | Event-driven; but uncertain JSON field names for `latam` identifier; untested in this config | Rejected |

**Rationale**: The `custom/*` pattern is the established convention in this waybar config. The scripts are deployed and tested. Native module migration is deferred per proposal scope.

### Decision: Polling interval of 5 seconds

| Option | Tradeoff | Decision |
|--------|----------|----------|
| 5s interval | Acceptable latency; low CPU (one `hyprctl` call per 5s) | **Chosen** |
| Signal-based (like `custom/iwd-wifi`) | Instant update; but requires kb-toggle.sh to emit a waybar signal — script change out of scope | Rejected |
| 1s interval | Faster feedback; unnecessary CPU for a layout indicator | Rejected |

**Rationale**: Matches spec requirement ("within 5 seconds"). Signal-based would be cleaner but requires modifying `kb-toggle.sh` to send `waybar-msg` — out of scope for this change.

### Decision: Module position before cpu in modules-right

**Choice**: Insert `"custom/language"` immediately before `"cpu"` in `modules-right`.
**Alternatives considered**: After battery (end), before bluetooth (start).
**Rationale**: Layout indicator is a quick-glance status item. Placing it next to cpu (another status widget) groups it with system indicators rather than connectivity widgets. Matches spec requirement.

## Data Flow

```
 ┌─────────┐  poll/5s   ┌──────────────┐  stdout    ┌─────────┐
 │  waybar  │───────────→│ kb-layout.sh │───────────→│ waybar  │
 │ (render) │            │ (hyprctl     │  "es" or   │ (display│
 │          │            │  keyboard-   │  "latam"   │  text)  │
 │          │            │  layout)     │            │         │
 └─────────┘            └──────────────┘            └─────────┘
      │                                                   ↑
      │ click                                             │ next poll
      ↓                                                   │
 ┌──────────────┐  hyprctl    ┌──────────────┐            │
 │ kb-toggle.sh │────────────→│  Hyprland    │────────────┘
 │ (cycle group │  switchxkb  │  XKB group   │  layout changed
 │  0 ↔ 1)     │  layout     │  0=es, 1=latam│
 └──────────────┘            └──────────────┘
```

**Alt+Shift path** (external toggle): User presses Alt+Shift → Hyprland changes XKB group → next 5s poll by `kb-layout.sh` picks up the change → waybar updates.

## File Changes

| File | Repo | Action | Description |
|------|------|--------|-------------|
| `config/waybar/config` | omarchy-nix | Modify | Add `"custom/language"` to `modules-right` (line 15, before `"cpu"`) + add module config block (~8 lines) |
| `flake.lock` | nixos-hosts | Auto-update | `nix flake lock --update-input omarchy-nix` after upstream merge (not a manual edit) |

**No changes to**:
- `hosts/t14/home/default.nix` — scripts already deployed
- `hosts/t14/home/hypr/input.nix` — XKB config already set
- `modules/home-manager/waybar.nix` — recursive copy already handles new config
- `flake.nix` — URL stays `github:glats/omarchy-nix/main`; only the lock file changes

## Interfaces / Contracts

### Waybar module config (JSON block in `config/waybar/config`)

```json
"custom/language": {
    "exec": "~/.local/share/omarchy/bin/kb-layout.sh",
    "interval": 5,
    "on-click": "~/.local/share/omarchy/bin/kb-toggle.sh",
    "format": "{} ",
    "tooltip": true
}
```

### Script contracts (unchanged, already deployed)

| Script | Input | Output | Side effect |
|--------|-------|--------|-------------|
| `kb-layout.sh` | none | stdout: `es` or `latam` (plain text) | none |
| `kb-toggle.sh` | none | none (fire-and-forget) | `hyprctl switchxkblayout keyboard group {0\|1}` |

**Error handling**: Both scripts use `2>/dev/null || echo "es"` / `|| true` fallbacks. If `hyprctl` fails (e.g., Hyprland not running), `kb-layout.sh` returns `"es"` as default. Waybar renders whatever stdout produces — no crash on empty/error output.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Config validation | JSON syntax, module key present | `nix flake check --no-build` on nixos repo after lock bump |
| Visual (t14) | Module appears in waybar right group | Run `nixos-build` on t14, verify "es" or "latam" visible |
| Click toggle | Click module → layout changes | Click widget, verify layout toggles, verify bar updates within 5s |
| Alt+Shift toggle | External toggle reflected in bar | Press Alt+Shift, verify bar updates within 5s |
| Tooltip | Hover shows layout name | Hover mouse over module, verify tooltip appears |
| No regression | Other modules unaffected | Verify cpu, battery, network, bluetooth, clock, tray all render correctly |

## Migration / Rollout

No migration required. This is an additive config change:
1. Merge omarchy-nix PR (adds module to waybar config)
2. Update flake lock on nixos-hosts: `nix flake lock --update-input omarchy-nix`
3. Build and switch on t14: `nixos-build`
4. Waybar restarts automatically (HM activation + `reload_style_on_change: true`)

Rollback: revert the omarchy-nix commit + re-lock → `nixos-build` restores previous config.

## Open Questions

- None. All dependencies (scripts, XKB config, waybar deployment) are verified in place.
