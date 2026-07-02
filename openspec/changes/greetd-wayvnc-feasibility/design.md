# Design: greetd + wayvnc — pre-login VNC on t14

## Technical Approach

Add an `omarchy.greeter.wayvnc` submodule to omarchy-nix that conditionally injects `exec-once = wayvnc <addr> <port> &` into the greeter Hyprland config **before** the existing `exec-once = greetd-regreet-start` line. Deploy the greeter's wayvnc config file via `systemd.tmpfiles.rules`. Opt in on t14 only.

References: proposal `openspec/changes/greetd-wayvnc-feasibility/proposal.md`, exploration `openspec/explore/greetd-wayvnc-feasibility/exploration.md`.

## Architecture Decisions

### Decision: Option placement — inside `greeter` submodule in `config.nix`

| Option | Tradeoff | Decision |
|--------|----------|----------|
| New `omarchy.greeter.wayvnc` submodule in `config.nix` | Co-located with sibling greeter options (type, keyboard, monitors, cursor); follows existing nesting pattern | **Chosen** |
| Separate top-level `omarchy.greeter-wayvnc` | Flat but breaks the greeter grouping | Rejected |
| Freeform `omarchy.greeter.preRegreetExec` list | Flexible but invites cargo-culting; no type safety for port/address | Rejected |

**Rationale**: `config.nix:284-353` already defines `greeter` as a submodule with `type`, `keyboard`, `monitors`, `cursor`. Adding `wayvnc` as a sibling option inside `greeter.options` (after `cursor` at line 348) follows the established pattern exactly.

### Decision: Injection point — string prepend in `environment.etc."greetd/hyprland.conf".text`

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `lib.optionalString` prepended to line 201 of `system.nix` | Minimal diff, conditional, follows existing `monitorBlock`/`cursorEnv` pattern | **Chosen** |
| Modify `greetd-regreet-start` shell script to launch wayvnc | Works but mixes Nix-level config with shell logic; harder to conditionally skip | Rejected |
| Separate `environment.etc` drop-in file | Hyprland config doesn't use `source=` or `conf.d`; would require structural changes | Rejected |

**Rationale**: Line 201 of `system.nix` already concatenates `monitorBlock`, `cursorEnv`, and `exec-once = ${greeterScript}`. Adding a `wayvncExec` let-bound value using `lib.optionalString` is the idiomatic approach and keeps the diff to ~5 lines.

### Decision: Config deployment — `systemd.tmpfiles.rules` (not HM for greeter user)

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `systemd.tmpfiles.rules` with `f` type | ~3 lines, no new HM user, owned by greeter:greeter | **Chosen** |
| `home-manager.users.greeter` | Cleaner HM path but expands HM surface for a system user | Rejected |
| `environment.etc."wayvnc/config"` system-wide | Would conflict with user-session per-user config at `~/.config/wayvnc/config` | Rejected |

**Rationale**: The `greeter` user is a system user (`isSystemUser = true`, home `/var/lib/greeter`). Creating a HM instance for it is disproportionate. `systemd.tmpfiles.rules` already used in `system.nix:54-56` for `/bin/bash` symlink — same pattern.

### Decision: Same port 5900 for greeter and user-session wayvnc

**Choice**: Same port (5900).
**Alternatives considered**: Different port (5901) to avoid disconnect blip.
**Rationale**: Greeter wayvnc and user-session wayvnc never run simultaneously (greetd session exits before user session starts). Remmina auto-reconnects on the same port during the ~1s handoff gap. Using the same port means zero client reconfiguration.

## Data Flow

```
 Boot
  │
  ▼
 greetd starts → spawns Hyprland as `greeter` user
  │                  (reads /etc/greetd/hyprland.conf)
  │
  ├── exec-once = wayvnc 0.0.0.0 5900 &    ← NEW (backgrounded)
  │     │
  │     ├── reads /var/lib/greeter/.config/wayvnc/config
  │     │     (address, port, enable_pam — deployed by tmpfiles)
  │     ├── inherits WAYLAND_DISPLAY, XDG_RUNTIME_DIR from Hyprland
  │     └── listens on 0.0.0.0:5900 (VeNCrypt + PAM)
  │
  ├── exec-once = greetd-regreet-start     ← EXISTING
  │     ├── disables eDP-1 if external monitor connected
  │     ├── launches regreet (GTK greeter)
  │     └── after regreet exits → hyprctl dispatch exit
  │
  ▼
 User authenticates via VNC (PAM) → regreet exits → Hyprland exits
  │
  ├── wayvnc process killed (parent Hyprland exits)
  ├── VNC client disconnects (~1s gap)
  │
  ▼
 User session starts → user wayvnc on same port 5900
  │
  └── VNC client auto-reconnects → desktop visible
```

## File Changes

### omarchy-nix (`/home/glats/repos/omarchy-nix`)

| File | Action | Lines | Description |
|------|--------|-------|-------------|
| `config.nix` | Modify | +18 | Add `wayvnc` submodule inside `greeter.options` (after line 348, before closing `};` on line 349). Options: `enable` (bool, default false), `address` (str, default "0.0.0.0"), `port` (port, default 5900), `enablePam` (bool, default true). |
| `modules/nixos/system.nix` | Modify | +8 | In the `environment.etc."greetd/hyprland.conf".text` let-block (lines 172-199): add `wayvncExec` let-binding using `lib.optionalString`. Prepend `${wayvncExec}` before `exec-once = ${greeterScript}` on line 201. Add `systemd.tmpfiles.rules` entry for `/var/lib/greeter/.config/wayvnc/config` gated on `cfg.greeter.wayvnc.enable`. |

**Exact injection in `system.nix`** (line 201 current):
```
${monitorBlock}${cursorEnv}exec-once = ${greeterScript}
```
Becomes:
```
${monitorBlock}${cursorEnv}${wayvncExec}exec-once = ${greeterScript}
```

Where `wayvncExec` is a new let-binding:
```nix
wayvncExec = lib.optionalString (cfg.greeter.wayvnc.enable)
  "exec-once = ${pkgs.wayvnc}/bin/wayvnc ${cfg.greeter.wayvnc.address} ${toString cfg.greeter.wayvnc.port} &\n";
```

**tmpfiles rule** (appended to existing `systemd.tmpfiles.rules` at line 54, gated by mkIf):
```nix
"f /var/lib/greeter/.config/wayvnc/config 0640 greeter greeter - ${wayvncConfigContent}"
```

Where `wayvncConfigContent` is:
```nix
wayvncConfigContent = lib.concatStringsSep "\\n" [
  "address=${cfg.greeter.wayvnc.address}"
  "port=${toString cfg.greeter.wayvnc.port}"
  "enable_pam=${if cfg.greeter.wayvnc.enablePam then "true" else "false"}"
];
```

### nixos-hosts (`/home/glats/.nixos`)

| File | Action | Lines | Description |
|------|--------|-------|-------------|
| `hosts/t14/default.nix` | Modify | +5 | Add `wayvnc = { enable = true; };` inside the existing `greeter = { ... }` block (after line 198, before closing `};` on line 199). Defaults for address/port/enablePam are inherited from config.nix. |

## Interfaces / Contracts

### New option tree

```
omarchy.greeter.wayvnc.enable      : bool   (default: false)
omarchy.greeter.wayvnc.address     : str    (default: "0.0.0.0")
omarchy.greeter.wayvnc.port        : port   (default: 5900)
omarchy.greeter.wayvnc.enablePam   : bool   (default: true)
```

### Generated artifacts (when enabled)

| Artifact | Path | Content |
|----------|------|---------|
| Hyprland config line | `/etc/greetd/hyprland.conf` | `exec-once = /nix/store/...-wayvnc-.../bin/wayvnc 0.0.0.0 5900 &` (BEFORE `exec-once = /nix/store/...-greetd-regreet-start`) |
| wayvnc config | `/var/lib/greeter/.config/wayvnc/config` | `address=0.0.0.0\nport=5900\nenable_pam=true` (owned by greeter:greeter, mode 0640) |

## Error Handling

| Failure mode | Behavior | Impact |
|-------------|----------|--------|
| wayvnc fails to start (port already bound) | Backgrounded process exits silently; regreet launches normally | Greeter works without VNC — additive, no regression |
| tmpfiles rule fails (greeter home missing) | NixOS activation reports warning; wayvnc falls back to built-in defaults | VNC uses wayvnc compiled-in defaults (no config file found) |
| PAM auth fails at VNC client | wayvnc rejects connection; regreet still visible | User retries with correct credentials |

No new failure modes that break the greeter. The `&` backgrounding ensures wayvnc failure does not block regreet.

## Rollback Plan

Two independent commits across two repos:

1. **omarchy-nix commit**: Add submodule + tmpfiles + exec-once injection. Revert: `git revert <sha>` in omarchy-nix, update flake lock in nixos-hosts.
2. **nixos-hosts commit**: Set `omarchy.greeter.wayvnc.enable = true` in t14. Revert: `git revert <sha>` in nixos-hosts (or set `enable = false`).

No state, no migration, no database. Each revert is a clean `nixos-build switch` away from the previous state.

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Evaluation | All hosts evaluate without errors | `nix flake check --no-build` |
| Build | t14 system closure builds | `nixos-build build` on t14 |
| Config inspection | `/etc/greetd/hyprland.conf` has wayvnc exec-once BEFORE greetd-regreet-start | `cat /etc/greetd/hyprland.conf \| grep -n wayvnc` |
| Config inspection | `/var/lib/greeter/.config/wayvnc/config` exists with correct content | `cat /var/lib/greeter/.config/wayvnc/config` |
| E2E | VNC to t14:5900 pre-login shows regreet; post-login auto-reconnects to desktop | Manual: cold-boot → Remmina connect → authenticate → observe reconnect |
| Negative | `enable = false` removes all greeter-wayvnc artifacts | Set false, rebuild, verify no wayvnc in hyprland.conf and no tmpfiles rule |

## Open Questions

None — all technical questions resolved during exploration and confirmed by source code reading.
