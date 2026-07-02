# Design: iwd-wifi waybar indicator → upstream omarchy-nix

## Technical Approach

Extract the inline iwd-wifi indicator script from t14's per-host config into omarchy-nix's shared `config/waybar/indicators/` directory, wire the `custom/iwd-wifi` module into the static waybar config, then delete the per-host block from nixos-hosts after bumping the flake lock. No Nix module changes needed — the existing `recursive = true` copy in `waybar.nix:10-13` auto-deploys any new file under `config/waybar/`.

This is Approach A (static unconditional add) from the proposal. The script emits disconnected-icon JSON on non-iwd systems, so it is safe on all hosts.

## Architecture Decisions

### Decision: Static-copy deployment (no Nix module changes)

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Add file to `config/waybar/indicators/` | Zero module changes; auto-deployed by `recursive = true` | **Chosen** |
| Add `xdg.configFile` entry in `waybar.nix` | Explicit but duplicates the recursive-copy pattern | Rejected |

**Rationale**: `modules/home-manager/waybar.nix:10-13` already does `source = ../../config/waybar; recursive = true`. Any file placed in `config/waybar/indicators/` is deployed automatically. Adding a separate Nix entry would create a second writer for the same path — unnecessary duplication.

### Decision: Signal 11 for iwd-wifi updates

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Signal 11 | Next free after 7, 8, 9, 10 | **Chosen** |
| Polling via `interval` | Simpler but wastes CPU cycles | Rejected |

**Rationale**: All existing custom indicators use signals (7=update, 8=screenrecording, 9=idle, 10=notification-silencing). Signal-based refresh matches the established pattern. Signal 11 is the next available number.

### Decision: Block placement after `network` in config

| Option | Tradeoff | Decision |
|--------|----------|----------|
| After `network` block (line 91) | Logical grouping — wifi-related modules adjacent | **Chosen** |
| After `custom/notification-silencing-indicator` (line 166) | Groups with other `custom/*` blocks | Rejected |

**Rationale**: The `custom/iwd-wifi` module is a WiFi fallback/complement to the built-in `network` module. Placing them adjacent improves readability and makes the relationship obvious to future maintainers.

### Decision: Direct commits on main (no branches)

**Choice**: Commit directly to `main` in both repos.
**Alternatives considered**: Feature branches + PRs.
**Rationale**: User explicitly requested direct commits. Both repos are owned by the same user. Rollback via `git revert` if needed.

## Data Flow

```
omarchy-nix repo                          nixos-hosts repo
─────────────────                         ────────────────
config/waybar/                            
├── config          ─── JSON block ───┐   
│   modules-right   ─── entry ────────┤   
├── indicators/                       │   
│   └── iwd-wifi.sh ──────────────────┤   
│                                       │
modules/home-manager/                   │
└── waybar.nix                          │
    recursive=true ─────────────────────┤
                                        │
    flake.lock ─────────────────────────┘
        nix flake update omarchy-nix
                                        │
    hosts/t14/home/default.nix ──── DELETE lines 58-80
```

1. omarchy-nix: script + config block committed to `main`
2. nixos-hosts: `nix flake update omarchy-nix` bumps `flake.lock` to pick up new commit
3. nixos-hosts: per-host iwd-wifi block deleted (omarchy's recursive copy now owns the path)
4. On `nixos-rebuild switch`: waybar.nix deploys entire `config/waybar/` dir → `~/.config/waybar/` → script runs via signal 11

## File Changes

| File | Repo | Action | Description |
|------|------|--------|-------------|
| `config/waybar/indicators/iwd-wifi.sh` | omarchy-nix | Create | Script extracted from t14 per-host config (lines 69-77). Add header comment documenting `wlan0` hard-code. `chmod +x`. |
| `config/waybar/config` | omarchy-nix | Modify | (1) Add `"custom/iwd-wifi"` to `modules-right` after `"network"` (line 12). (2) Insert `custom/iwd-wifi` JSON block after `network` block (after line 91). |
| `hosts/t14/home/default.nix` | nixos-hosts | Modify | (1) Delete lines 58-80 (comment header + `home.file` block). (2) Delete line 8 from top comment (`#   - iwd-wifi waybar indicator script (iwd-specific, not in omarchy)`). |
| `flake.lock` | nixos-hosts | Modify | `nix flake update omarchy-nix` to pick up omarchy-nix main. |

### Exact content: `config/waybar/indicators/iwd-wifi.sh`

```bash
#!/bin/bash
# waybar custom module: iwd WiFi status
# Deployed via omarchy-nix config/waybar/ (recursive copy).
# Limitation: wlan0 is hard-coded — matches system.nix:230 convention.
state=$(iwctl station wlan0 show 2>/dev/null | awk '/State/ {print $2}')
ssid=$(iwctl station wlan0 show 2>/dev/null | awk '/Connected network/ {$1=""; $2=""; print}' | xargs)
if [ "$state" = "connected" ] && [ -n "$ssid" ]; then
  echo "{\"text\": \" $ssid\", \"class\": \"connected\", \"tooltip\": \"WiFi: $ssid (iwd)\"}"
else
  echo "{\"text\": \"󰤮\", \"class\": \"disconnected\", \"tooltip\": \"WiFi disconnected\"}"
fi
```

### Exact edit: `config/waybar/config` — `modules-right` (line 9-16)

```json
  "modules-right": [
    "group/tray-expander",
    "bluetooth",
    "network",
    "custom/iwd-wifi",
    "pulseaudio",
    "cpu",
    "battery"
  ],
```

### Exact edit: `config/waybar/config` — new block after line 91

```json
  "custom/iwd-wifi": {
    "exec": "~/.config/waybar/indicators/iwd-wifi.sh",
    "signal": 11,
    "return-type": "json",
    "on-click": "omarchy-launch-wifi"
  },
```

### Exact deletion: `hosts/t14/home/default.nix`

- **Line 8**: Delete `#   - iwd-wifi waybar indicator script (iwd-specific, not in omarchy)`
- **Lines 58-80**: Delete entire block (comment header + `home.file` declaration)

After deletion, line 57 (`};`) connects directly to line 81 (`}`), closing the config.

## Interfaces / Contracts

### Waybar custom module JSON contract

The script emits JSON to stdout matching waybar's custom module protocol:

```json
{
  "text": " string — displayed in bar",
  "class": "connected | disconnected — CSS class for styling",
  "tooltip": "string — hover tooltip"
}
```

Signal 11 triggers re-execution (external processes can `pkill -RTMIN+11 waybar` to refresh).

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Flake validation | Both repos evaluate without errors | `nix flake check --no-build` in each repo |
| Format check | Nix files pass formatter | `format-nix` in nixos-hosts, `nix fmt -- .` in omarchy-nix |
| Script execution | Script runs and emits valid JSON | Manual: `bash config/waybar/indicators/iwd-wifi.sh` on t14 |
| Visual | Indicator appears in waybar | `nixos-rebuild switch` on t14, confirm bar shows WiFi SSID or disconnected icon |

No automated test harness exists in omarchy-nix (`testing.test_runner: null`). Validation is flake check + format + visual confirmation.

## Migration / Rollout

**Commit sequence (order matters — omarchy-nix first):**

1. **omarchy-nix main**: Create `config/waybar/indicators/iwd-wifi.sh` (chmod +x), edit `config/waybar/config` (add modules-right entry + JSON block). Validate with `nix flake check` + `nix fmt`. Commit.
2. **nixos-hosts**: Run `nix flake update omarchy-nix` to bump lock. Edit `hosts/t14/home/default.nix` (delete lines 8, 58-80). Validate with `nix flake check --no-build` + `format-nix`. Commit.

**Rollback**: Independent `git revert` in each repo. Order-agnostic — nixos-hosts revert restores per-host block; omarchy-nix revert removes upstream copy. Both can coexist temporarily (duplicate deploy, no conflict).

## Open Questions

None.
