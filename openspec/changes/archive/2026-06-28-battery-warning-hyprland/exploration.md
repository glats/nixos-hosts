# Exploration: Battery Warning & Critical-Battery Behavior on t14 (Omarchy/Hyprland)

> Investigation answer — two-part summary:
>
> 1. **Low-battery notification: PARTIAL.** Omarchy-nix ships a `omarchy-battery-monitor`
>    systemd user service + a Waybar `battery` module. The waybar widget works
>    today (reads sysfs directly). The notification daemon-side service is
>    registered but is **likely dead-on-arrival** on the t14 because the
>    script depends on the `upower` CLI / D-Bus service, and **`services.upower`
>    is not enabled** anywhere in the repo (not in the omarchy-nix NixOS
>    module, not in `modules/hardware/amd-laptop.nix`, not in
>    `hosts/t14/default.nix`, not in the t14 home config). It works on systems
>    where some other module pulls it in (e.g. GNOME), but on t14 it is
>    unreliable.
>
> 2. **What happens at critical battery: NOTHING AUTOMATIC.** No hibernate,
>    no graceful shutdown, no UPower `criticalPowerAction`, no logind critical
>    action. The system will run the battery flat and power off abruptly
>    (dirty shutdown, potential filesystem corruption, lose unsaved work).
>    The `omarchy-battery-monitor` only sends a 30-second mako notification
>    at ≤10% — there is no `battery-critical` hook or automatic action.
>    `modules/base/logind.nix` configures `HandleHibernateKey =
>    "hibernate"` and `HandlePowerKey = "poweroff"`, but neither of those
>    triggers on a battery event — they are key-driven.

This document explains what is there, what is missing, and what the
recommended change looks like.

---

## Current State

### 1. What omarchy-nix provides

Omarchy-nix (`github:glats/omarchy-nix/main`, see `flake.nix:19-23`)
contributes the battery pipeline via three pieces:

#### a. `omarchy-battery-monitor` (notification service)

`omarchy-nix/modules/home-manager/battery-monitor.nix` registers a systemd
**user** service:

```nix
systemd.user.services.omarchy-battery-monitor = {
  Unit = {
    Description = "Omarchy Battery Monitor";
    After = ["graphical-session.target"];
  };
  Service = {
    Type = "simple";
    ExecStart = "${config.home.homeDirectory}/.local/share/omarchy/bin/omarchy-battery-monitor";
    Restart = "on-failure";
    RestartSec = 10;
  };
  Install.WantedBy = ["graphical-session.target"];
};
```

The script at `omarchy-nix/bin/omarchy-battery-monitor` (deployed to
`~/.local/share/omarchy/bin/`) is the load-bearing piece:

```bash
BATTERY_THRESHOLD=10
NOTIFICATION_FLAG="/run/user/$UID/omarchy_battery_notified"
BATTERY_LEVEL=$(omarchy-battery-remaining)
BATTERY_STATE=$(upower -i $(upower -e | grep 'BAT') | grep -E "state" | awk '{print $2}')

send_notification() {
  notify-send -u critical " Time to recharge!" "Battery is down to ${1}%" -i battery-caution -t 30000
  omarchy-hook battery-low "$1"
}

if [[ -n $BATTERY_LEVEL && $BATTERY_LEVEL =~ ^[0-9]+$ ]]; then
  if [[ $BATTERY_STATE == "discharging" ]] && (( BATTERY_LEVEL <= BATTERY_THRESHOLD )); then
    if [[ ! -f $NOTIFICATION_FLAG ]]; then
      send_notification $BATTERY_LEVEL
      touch $NOTIFICATION_FLAG
    fi
  else
    rm -f $NOTIFICATION_FLAG
  fi
fi
```

Behavior:

- 10% threshold (hard-coded in the script).
- Fires a **single** mako critical notification per discharge cycle (the
  `$NOTIFICATION_FLAG` suppresses repeats).
- Calls `omarchy-hook battery-low "$1"` — that hook is the **user-extensible
  extension point** (a script dropped at
  `~/.config/omarchy/hooks/battery-low` or `battery-low.d/*` is invoked with
  the percentage as `$1`). The hook can do anything the user wants
  (auto-suspend, log a message, toggle power profile, …). Nothing exists
  there by default.
- The service is `Type=simple` with `Restart=on-failure, RestartSec=10`.
  The script has no main loop, so it exits after one check — systemd
  restarts it every 10s, giving an effective 10-second poll. Cheap (one
  `upower -i` call) but not energy-aware.

#### b. Waybar `battery` module (always-on indicator)

`omarchy-nix/config/waybar/config` lines 94-112:

```json
"battery": {
  "format": "{capacity}% {icon}",
  "format-discharging": "{icon}",
  "format-charging": "{icon}",
  "format-plugged": "",
  "format-icons": { ... },
  "format-full": "",
  "tooltip-format-discharging": "{power:>1.0f}W↓ {capacity}%",
  "tooltip-format-charging": "{power:>1.0f}W↑ {capacity}%",
  "interval": 5,
  "on-click": "omarchy-menu power",
  "states": {
    "warning": 20,
    "critical": 10
  }
}
```

This is the always-visible waybar widget: percentage + icon, with a
warning state at 20% and a critical state at 10%. Clicking it opens
`omarchy-menu power` (the power menu). It reads sysfs/UPower directly
through waybar's built-in battery module — does **not** depend on
`services.upower`. **This part works today on t14 regardless of the
upower D-Bus service.**

#### c. Mako notification daemon

`omarchy-nix/modules/home-manager/mako.nix` enables `services.mako.enable`
and wires the config to the active theme. Mako is what shows the
"Time to recharge!" notification. It is started by Hyprland's autostart
pipeline and is part of the graphical session. **This is fine.**

### 2. What the t14 host configures

- `hosts/t14/default.nix` — does **not** configure battery, upower,
  logind critical action, or a hibernate target. Imports
  `modules/hardware/amd-laptop.nix` and `modules/base/logind.nix`.
- `modules/hardware/amd-laptop.nix` — enables
  `services.power-profiles-daemon` and `services.fwupd`, but does **not**
  enable `services.upower`. `power-profiles-daemon` does not pull in
  upower as a dependency.
- `modules/base/logind.nix` — `HandlePowerKey=poweroff`,
  `HandleSuspendKey=suspend`, `HandleHibernateKey=hibernate`,
  `HandleLidSwitch=ignore`, `IdleAction=ignore`. **No** `HandleCriticalPower`
  / `CriticalPowerAction` / hibernate-on-low-battery directives.
- `hosts/t14/home/omarchy.nix` — overrides `services.hypridle.settings`
  (lock/screensaver timings). No battery-related config. No
  `~/.config/omarchy/hooks/battery-low` user hook defined anywhere.

### 3. The `upower` gap

The notification script calls `upower -i $(upower -e | grep 'BAT')` to
read battery state. The `upower` CLI requires the UPower D-Bus service to
be running — `upower -e` enumerates D-Bus devices, and `upower -i <path>`
queries D-Bus properties. Without the service, both calls fail silently
and return empty strings.

`services.upower.enable` defaults to `false` in nixpkgs. Searching the
entire repo:

```
$ grep -rn "services\.upower\|upower\.enable" /home/glats/.nixos
# (no matches)
$ grep -rn "upower" /home/glats/repos/omarchy-nix/modules/nixos
# (no matches)
```

Confirmed via `nix eval` against the omarchy-nix flake:
`services.upower.enable` resolves to "missing" (i.e. unset, default
false). On GNOME, `services.desktopManager.gnome.enable = true` pulls in
`services.upower.enable = true` as a dependency. Hyprland does not —
omarchy-nix is Hyprland-only and does not enable gnome-desktop on t14.

Waybar's battery module, by contrast, falls back to sysfs
(`/sys/class/power_supply/BAT0/...`) when UPower D-Bus is unavailable, so
the widget in the panel still works. That is the asymmetry: **the panel
indicator works, the notification does not.**

### 4. What happens at 0% / battery removed / AC unplugged

Nothing automatic. Walk-through:

1. Battery drains below 10% — `omarchy-battery-monitor` *should* fire
   `notify-send -u critical "Time to recharge!"`. **But: only if upower
   D-Bus is running.** On t14 today it is not, so the mako notification
   never appears and the user hook `battery-low` is never called.
2. Waybar widget turns red at 10% (still works).
3. Battery continues to drain past 0% — no `HandleCriticalPower` directive
   in `logind.conf`, no UPower `percentageAction` configured, no
   `battery-critical` hook, no systemd hibernate target triggered.
4. Battery hits 0% and the EC (embedded controller) cuts power. The
   system powers off abruptly. Journald is not flushed, filesystems may
   be dirty, in-flight btrfs subvolume writes can be lost. The next boot
   goes through `btrfs scrub` / `fsck` (which on t14 with btrfs root
   is `btrfs check --readonly` plus the kernel's recovery code, but
   btrfs tolerates abrupt shutdowns better than ext4).

This is the **critical-battery behavior** the user is asking about. It
is effectively "dirty poweroff when EC cuts power".

### 5. Hibernation prerequisites (in case we add it)

The t14 currently **does not have hibernate configured**. To enable
hibernate (suspend-to-disk), three things are needed:

1. Swap space at least equal to RAM size (or a dedicated hibernate
   partition). The t14 already has `boot.swapFile` or `zramSwap` — but
   `zramSwap` (set by `modules/hardware/amd-laptop.nix:13`) is **not** a
   hibernate target. Real swap on disk is required.
2. `boot.kernelParams = [ "resume=/dev/..." ]` or
   `resume_offset=` / `resume_device=` for a swap file. The kernel
   `amdgpu` driver supports S4.
3. `boot.resumeDevice` set in NixOS, or the equivalent
   `systemd.hibernate` settings, and the initrd must include the
   resume hook.

These are non-trivial to add. **A graceful `poweroff` at 5% is much
cheaper to wire up and covers 95% of the user-facing risk.**

---

## Affected Areas

| File | Why it is relevant |
|------|--------------------|
| `hosts/t14/default.nix` | Where `services.upower` and `services.logind` critical-power settings would be enabled. Currently imports `amd-laptop.nix` and the base `logind.nix`. |
| `modules/hardware/amd-laptop.nix` | The right home for `services.upower.enable = true;` and any `criticalPowerAction` / `percentageAction`. Already imports `power-profiles-daemon`. |
| `modules/base/logind.nix` | Cross-host logind settings. Could add `HandleCriticalPowerAction` here, or override per-host. Currently lacks any critical-power policy. |
| `hosts/t14/home/omarchy.nix` | Where a `~/.config/omarchy/hooks/battery-low` user hook (the omarchy extension point) could be defined. Optional. |
| `omarchy-nix/modules/home-manager/battery-monitor.nix` | Upstream. Out of scope for this repo (we don't patch omarchy-nix for this; we either enable upower here or replace the monitor with our own). |
| `omarchy-nix/bin/omarchy-battery-monitor` | Upstream script. Out of scope. We can influence it via the `battery-low` hook. |
| `omarchy-nix/config/waybar/config` (line 94-112) | Upstream waybar config. The "critical" state (10%) styling is here. Out of scope. |
| `flake.nix` (line 19-23) | Where `omarchy-nix` is pinned. No change needed. |

---

## Approaches

### Option A — Enable `services.upower` only (small, surfaces the notification)

Add `services.upower.enable = true;` to `modules/hardware/amd-laptop.nix`
(so all AMD-laptop hosts get it). The D-Bus service starts, the
`omarchy-battery-monitor` script starts working, and the user gets a
mako critical notification at ≤10% with the `battery-low` hook firing.
**No new code, ~2 lines.**

- **Pros**: Minimal change. Uses the upstream-provided extension point.
  Waybar widget already works; this just makes the notification fire.
- **Cons**: No critical-power action. At 0% the system still powers off
  abruptly. Doesn't answer the second half of the user's question.
- **Effort**: Very low (1-2 lines, one file).

### Option B — Enable upower + UPower critical-power action (Hibernate at 5%)

Option A **plus** configure UPower to suspend/hibernate/poweroff when the
battery hits a low-percentage threshold:

```nix
services.upower = {
  enable = true;
  percentageLow = 15;       # warning level (informational)
  percentageCritical = 8;   # critical level
  percentageAction = 5;     # at 5%, take the action below
  criticalPowerAction = "PowerOff"; # or "Hibernate" (requires swap+resume=)
};
```

- **Pros**: Closes both halves of the question. At 5% the laptop
  auto-powers off cleanly, journald flushes, btrfs stays clean. No
  reliance on user hooks.
- **Cons**: `Hibernate` requires real disk swap (not `zramSwap`) and
  `boot.kernelParams` / `boot.resumeDevice` wiring — that is its own
  multi-file change. `PowerOff` is the easier alternative and is
  almost-as-good: it triggers `systemd-poweroff` which flushes
  filesystems in an orderly way (still risk of data loss, but no
  filesystem corruption).
- **Effort**: Low for `PowerOff` (~5 lines), Medium for `Hibernate`
  (requires swap file/partition + kernel param + initrd changes).

### Option C — Add a `battery-low` user hook on t14 (informational, complementary)

Drop a small script at `~/.config/omarchy/hooks/battery-low` via
`hosts/t14/home/omarchy.nix` (using `home.file`) that does something
user-visible — e.g. log to a file, switch power profile to
"power-saver", or show a custom mako notification. This is purely
additive and is the omarchy-native extension point.

- **Pros**: User-customizable. Doesn't fight omarchy's design.
- **Cons**: Only fires if Option A or B is also applied (still depends
  on upower D-Bus running).
- **Effort**: Very low.

### Option D — Replace the monitor with a per-host systemd timer (most robust)

Skip omarchy's `omarchy-battery-monitor` entirely. Write a small NixOS
service + timer in `modules/features/services/battery-monitor.nix` (or
`hosts/t14/services/battery-monitor.nix`) that uses
`/sys/class/power_supply/BAT0/capacity` and
`/sys/class/power_supply/BAT0/status` directly (no D-Bus dependency) and
fires `notify-send` + a `battery-low` hook + a critical action.

- **Pros**: No D-Bus dependency, fully self-contained, can include
  critical-power action in the same module. Cleaner mental model.
- **Cons**: Reinvents what omarchy already provides. Diverges from
  upstream — future omarchy-nix updates to the monitor (e.g. a 5%
  critical level) won't reach the t14 unless we sync.
- **Effort**: Medium (new file, ~30 lines of nix + bash, new systemd
  unit, a host-import).

---

## Recommendation

**Apply Option B (PowerOff variant) + Option C as a small follow-up.**

1. **Step 1 — Enable upower + poweroff on critical battery** in
   `modules/hardware/amd-laptop.nix`:

   ```nix
   services.upower = {
     enable = true;
     percentageLow = 15;
     percentageCritical = 8;
     percentageAction = 5;
     criticalPowerAction = "PowerOff"; # or "Hibernate" if/when disk swap is wired
   };
   ```

   This:
   - Fixes the notification gap (omarchy's `omarchy-battery-monitor`
     starts working).
   - Adds a graceful poweroff at 5% — the EC no longer wins the race to
     cut power. Journald flushes, btrfs stays consistent.
   - Lives in `amd-laptop.nix` (host-conditional on the t14 import) so
     it doesn't affect rog/thinkcentre (which have no battery).

2. **Step 2 — Optionally add a `battery-low` user hook** in
   `hosts/t14/home/omarchy.nix` (a no-op `echo` or a power-profile
   switch), demonstrating the omarchy extension point and giving the
   user a place to plug in custom behavior later. This is nice-to-have,
   not required for the user's question.

3. **Do not pursue Hibernate** in this change. The disk-swap / resume=
   wiring is a multi-file refactor with its own risks (resume
   partition sizing, initrd hook). `PowerOff` at 5% is a strictly better
   outcome than "EC cuts power at 0%" and the diff is ~5 lines.

4. **Document the behavior** in a comment block at the top of
   `modules/hardware/amd-laptop.nix` so future sessions don't
   re-investigate.

### Trade-off: Why not Hibernate

Hibernate is strictly nicer (you resume your session exactly where you
left it, with all applications open). But it requires:

- A swap file or partition ≥ RAM size.
- `boot.kernelParams = [ "resume=..." ]` (or `boot.resumeDevice`).
- The initrd to include the `resume` hook.

The t14 currently has `zramSwap.enable = true` in
`modules/hardware/amd-laptop.nix:13`. zram is a **RAM-backed compressed
swap**, not disk-backed — it cannot be used for hibernate. Adding real
swap is a separate change (could be a follow-up SDD change). For the
"don't lose data on critical battery" goal, `PowerOff` is sufficient.

---

## Risks

- **Boot-time impact of enabling `services.upower`.** None observed
  historically; the service is a small D-Bus daemon. Rog and thinkcentre
  do not import `amd-laptop.nix` (only t14 does), so this change is
  scoped to t14 automatically.
- **Critical-power action fire rate.** `percentageAction = 5` means the
  action fires **once per discharge cycle** when the battery crosses
  5%. If the user plugs in before 5%, the action never fires. The
  threshold is reasonable for a laptop — by 5% the user has had the 10%
  warning for several minutes.
- **`PowerOff` is destructive.** Whatever is in RAM (open files,
  browser tabs, vim buffers) is lost. Same as the EC abruptly cutting
  power, except the journald flush + orderly `systemctl stop` of
  services happens first. **There is no way to preserve state without
  hibernate (or suspend) — and suspend needs RAM to stay powered, which
  on a 0% battery is impossible.** This is the best we can do without
  hibernate support.
- **UPower `criticalPowerAction` requires the user to be logged in /
  D-Bus session active for the action to dispatch.** UPower itself is a
  system service, but the `percentageAction` threshold is checked by
  the UPower daemon (a system-level D-Bus service), not by the user
  session. So the action fires even if no user is logged in (rare on a
  laptop, but possible if locked at the greeter). Good.
- **Waybar "critical" state styling at 10%.** Cosmetic — the icon turns
  red. Independent of the upower service. Still works after the change.
- **Interaction with `services.power-profiles-daemon`.** None. ppd is a
  separate service. The hook can also set the profile (Option C), but
  that is independent.
- **omarchy-nix upstream divergence.** We are not changing the omarchy
  monitor. We are only enabling a service in the t14 config. If
  omarchy-nix later moves to a non-upower monitor, our `services.upower`
  enable becomes a no-op (no harm). If they add a `battery-critical`
  hook that fires before the UPower action threshold, there is a small
  risk of duplicate action (e.g. omarchy sends a notification AND
  upower powers off at 5%). Acceptable for now; revisit if upstream
  adds critical-power logic.
- **The user has `HandleLidSwitch=ignore` in `modules/base/logind.nix:8`.**
  This is the existing behavior on rog/thinkcentre/t14 — closing the lid
  does not sleep. Not affected by this change, but worth flagging as
  "if you want to use suspend-on-low-battery (instead of poweroff),
  you may also want to revisit the lid-switch policy". Out of scope
  here.

---

## Architectural Pattern Analysis (Follow-up)

> The user asked two follow-up questions before signing off on the
> recommended approach:
>
> 1. Does omarchy-nix already provide a default UPower configuration
>    (even if not enabled)?
> 2. What is the established pattern in nixos-hosts for consuming
>    omarchy-nix service defaults vs defining them from scratch?

This section answers both with code-level evidence from the omarchy-nix
source (pinned to `60d7f681ab6906fa42a96b213d979eb1da2414f3` per
`flake.lock:1096`) and the nixos-hosts repo.

### Q1: Does omarchy-nix provide any UPower / battery NixOS defaults?

**No.** Verified by exhaustively reading every `.nix` file in
`omarchy-nix/modules/nixos/` (14 files) and grepping the entire
`omarchy-nix/modules/` tree for `upower`, `battery`, and `power`:

| Grep target | Hits in `omarchy-nix/modules/nixos/` | Hits in `omarchy-nix/modules/home-manager/` |
|-------------|--------------------------------------|---------------------------------------------|
| `upower` | 0 | 0 |
| `services\.upower` | 0 | 0 |
| `battery` | 0 | 1 (`battery-monitor.nix` — HM user service, no NixOS option) |
| `power-profiles` | 1 (`system.nix:264` — `services.power-profiles-daemon.enable = true`) | 0 |

The only `services.*` enabled in omarchy-nix's `modules/nixos/system.nix`
related to power is `services.power-profiles-daemon.enable = true`
(line 264) — a separate service that manages performance/balanced/
power-saver profiles via D-Bus. It is **not** a UPower replacement and
does **not** pull in `services.upower` as a dependency
(confirmed: nixpkgs `services.power-profiles-daemon` and
`services.upower` are independent service definitions).

The `omarchy-nix/modules/home-manager/battery-monitor.nix` module is a
**home-manager** module that registers a `systemd.user.services` unit
executing `omarchy-battery-monitor` (a bash script that calls `upower
-i`). It is a CONSUMER of UPower, not a PROVIDER. It assumes the
`upower` D-Bus service is already running on the host — which on
Hyprland+omarchy it is not, because nothing in omarchy-nix enables it.

**Net**: omarchy-nix is silent on `services.upower`. There are no
defaults to consume, no `lib.mkDefault` values to override, and no
options to flip. The NixOS-level gap is a **blank slate**.

### Q2: Established pattern in nixos-hosts — consume or define locally?

The pattern is **mixed** and falls into two clear buckets depending on
whether the service is a desktop-wide concern or hardware-specific.
Verified by grepping the repo for each service.

#### Bucket A: Service enabled by omarchy-nix → nixos-hosts does NOT redeclare

omarchy-nix's `system.nix` enables these unconditionally; the t14 host
config and the AMD-laptop module both stay silent on them. The
omarchy-defined value wins by virtue of being the only definition.

| Service | Defined in omarchy-nix | Defined in nixos-hosts? |
|---------|------------------------|-------------------------|
| `services.pipewire` | `system.nix:58-63` (alsa/pulse/jack) | No — t14 does not import pipewire.nix |
| `services.pulseaudio.enable = false` | `system.nix:57` | No |
| `services.gvfs.enable = true` | `system.nix:255` | No |
| `services.printing.enable = true` | `system.nix:258-261` | No |
| `services.gnome.gnome-keyring.enable = true` | `system.nix:267` | No |
| `services.resolved.enable = true` | `system.nix:272` | No |
| `hardware.bluetooth.enable = true` | `system.nix:273` | No |
| `services.avahi.enable = true` | `system.nix:243-254` | Yes (in `modules/networking/avahi.nix`) — but both are unconditional; values match. |
| `services.power-profiles-daemon.enable = true` | `system.nix:264` | Yes (in `modules/hardware/amd-laptop.nix:11` with `lib.mkDefault`) — `mkDefault` lets omarchy's value win if it ever gets pkged into the right order, but currently both are `true` and `mkDefault` lets the local amd-laptop value stay. |

The nixos-hosts repo's stance for desktop-wide services is **"consume
omarchy's default and do not redeclare"**. This is explicit in the
t14 `default.nix` comment block (lines 33-37): "Omarchy provides
Hyprland + PipeWire + NetworkManager + Bluetooth + printing + gvfs.
The previous GNOME module ... and avahi module ... are no longer
imported because omarchy's system.nix supersedes them."

#### Bucket B: Hardware-specific service → nixos-hosts defines locally

When the service is tied to specific hardware (laptop, GPU, vendor),
the nixos-hosts repo defines it locally in `modules/hardware/*.nix`
and the host imports the hardware module explicitly. omarchy-nix does
not touch these (it is a generic desktop flake — hardware-agnostic).

| Service | Where defined | Why local |
|---------|---------------|-----------|
| `services.fwupd.enable = true` | `modules/hardware/amd-laptop.nix:10` | Vendor firmware updater; only relevant on AMD laptops (t14). |
| `services.power-profiles-daemon.enable = true` | `modules/hardware/amd-laptop.nix:11` (`lib.mkDefault`) | Co-located with `fwupd`; `mkDefault` is defensive. (Also redundantly set by omarchy-nix — see Bucket A row.) |
| `services.xserver.videoDrivers = [ "nvidia" ]` | `modules/hardware/nvidia.nix:38` | rog-only. |
| `hardware.nvidia.*` | `modules/hardware/nvidia.nix` (entire module) | rog-only. |
| `services.asus-fan-control` (custom systemd unit) | `modules/hardware/asus-fan-control.nix` | rog-only (custom opt-in `asus-fan-control-custom.enable`). |
| `hardware.cpu.amd.updateMicrocode = true` | `modules/hardware/amd-laptop.nix:7` | AMD-specific. |
| `zramSwap.enable = true` | `modules/hardware/amd-laptop.nix:13` | Laptop-tuned. |

The pattern is: **a service that only some hosts need (a hardware
filter) lives in `modules/hardware/*.nix`**, and the host that needs
it imports the module. rog imports `nvidia.nix` and
`asus-fan-control.nix`. t14 imports `amd-laptop.nix`. thinkcentre
imports nothing from `hardware/` (it is a desktop tower with no
laptop/GPU-specific needs).

#### What this means for `services.upower`

`services.upower` is unambiguously in **Bucket B**:

1. Only laptops with batteries need it. rog (desktop, no battery) and
   thinkcentre (headless tower, no battery) do not.
2. omarchy-nix does not enable it (Q1 answer above), so there is no
   upstream default to consume.
3. The closest analog is `services.fwupd.enable` (line 10 of
   `amd-laptop.nix`) and `services.power-profiles-daemon.enable` (line
   11) — both laptop-only, both enabled in `amd-laptop.nix` with no
   omarchy-nix involvement on the t14 path.
4. Putting `services.upower` in `modules/hardware/amd-laptop.nix`
   scopes it correctly to t14 automatically (only t14 imports the
   module — see `hosts/t14/default.nix:43`).

### Recommendation (confirmed)

The proposed approach in §"Recommendation" above (Option B / PowerOff
variant — `services.upower = { enable = true; ... }` in
`modules/hardware/amd-laptop.nix`) is the right call and follows the
established pattern.

**No new file.** No new module split. No "should this be a default
consumed from omarchy-nix" patch upstream — there is no upstream
default to consume, and creating one would mean changing the
ownership boundary (omarchy is supposed to be desktop-agnostic;
hardware battery policy is a per-host concern).

If we ever wanted a different boundary, the right move would be to
add a `modules/features/services/upower.nix` (the
`features/services/` directory is the home for opt-in service
modules — see `xrdp.nix`, `github-mcp-server.nix`). But that would
require a per-host opt-in (`hosts/t14/default.nix` would import it
explicitly, and `amd-laptop.nix` would not). That is strictly more
files for no benefit, so the single-block addition to
`amd-laptop.nix` is the right granularity.

---

## Ready for Proposal

**Yes.**

The recommended change is small (≈5 lines of nix in
`modules/hardware/amd-laptop.nix` plus a comment block) and
self-contained. The proposal should:

- State intent: "ensure the t14 sends a low-battery notification and
  powers off cleanly at 5% battery, rather than relying on the EC to
  abruptly cut power at 0%."
- Scope: `modules/hardware/amd-laptop.nix` (host-conditional on t14
  import). Optionally: `hosts/t14/home/omarchy.nix` for the user hook.
- Non-scope: hibernate (separate change requiring disk swap),
  `services.upower` for rog/thinkcentre (no battery), lid switch
  policy.
- Verify: on the live t14, simulate by lowering `percentageAction` to
  99% and confirming the system gracefully powers off; revert after
  the test.
- Spec scenarios: (1) when battery < 10% and discharging, mako
  notification appears once; (2) when battery < 5% and discharging,
  the system powers off gracefully (journald flushes, clean btrfs
  state); (3) when AC is plugged in, neither fires.

The 400-line review budget is **not** a concern here (delta is < 30
lines). No chained PR needed.
