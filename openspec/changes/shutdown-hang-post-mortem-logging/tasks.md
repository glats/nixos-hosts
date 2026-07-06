# Tasks: Shutdown Hang — Iteration 3 (Sequential Apply)

> **Change**: shutdown-hang-post-mortem-logging
> **Iteration**: 3
> **Strategy**: 4 sequential apply slices (A->B->C->D), each tested before next
> **Delivery**: single-pr (each slice is small, under 400 lines total)

## Review Workload Forecast

| Metric | Value |
|--------|-------|
| Total estimated lines changed | ~120 (across all 4 slices) |
| Files modified (all slices) | 2 existing, 1 new |
| Per-slice max lines | ~40 (slice 4 is largest) |
| **Decision needed before apply** | **No** |
| **Chained PRs recommended** | **No** |
| **400-line budget risk** | **Low** |

Each slice is small enough to verify independently. The orchestrator deploys and tests each slice before launching the next. No exception request needed.

---

## Phase 1: Slice A — Module Blacklist

**Goal**: Blacklist `asus_nb_wmi` and `asus_armoury` kernel modules on rog. Test shutdown. STOP.

### Tasks

- [ ] **1.1** Add `boot.blacklistedKernelModules = [ "asus_nb_wmi" "asus_armoury" ]` to `hosts/rog/default.nix`
  - Insert after the existing `boot` block (around line 84, after `kernelModules`)
  - Do NOT blacklist `asus_wmi`, `hid_asus`, or `acpi_call`
  - Existing rmmod in `modules/hardware/rog-poweroff-workaround.nix` already tolerates absent modules via `|| true`

- [ ] **1.2** Run `format-nix && nix flake check --no-build` to validate

**User test gate**: Deploy to rog, verify via `lsmod | grep asus_nb_wmi` (should be absent), test shutdown. If hangs stop, DONE. If not, proceed to Phase 2.

---

## Phase 2: Slice B — Add OSI Policy Change

**Goal**: Remove ACPI OSI kernel params from rog boot. Test shutdown. STOP.

### Tasks

- [ ] **2.1** In `hosts/rog/default.nix`, change `includeAcpiOsi = true;` to `includeAcpiOsi = false;` (line 63)
  - This removes `acpi_osi=!` and `acpi_osi="Windows 2018"` from the kernel command line
  - The conditional in `modules/features/boot.nix` (line 55) handles the rest — no changes needed there

- [ ] **2.2** Run `format-nix && nix flake check --no-build` to validate

**User test gate**: Deploy to rog, verify `/proc/cmdline` no longer contains `acpi_osi`, test shutdown. If hangs stop, DONE. If not, proceed to Phase 3.

---

## Phase 3: Slice C — Add DSDT Override (Module Structure)

**Goal**: Create DSDT override module with enable option. Provide structure for offline DSDT dump/patch/reassemble. Test build. STOP.

### Tasks

- [ ] **3.1** Create `modules/hardware/rog-dsdt-override.nix` with:
  - Option `hardware.rog.dsdtOverride.enable` (mkEnableOption, default false)
  - When enabled, set `hardware.acpiTables = [ ./rog-dsdt.aml ]` (or similar path under `hosts/rog/acpi/`)
  - Guard: module only applies on rog (check hostname or use host-level import)
  - Guard: file must exist at the path or emit a clear assertion message
  - Reference: `hardware.acpiTables` is the NixOS option for injecting ACPI table overrides

- [ ] **3.2** Create directory `hosts/rog/acpi/` with a placeholder README.md documenting the offline DSDT workflow:
  - `acpidump` to extract current DSDT
  - `iasl -d` to disassemble
  - Patch the .dsl to address the power-off hang (specific edits TBD by user during offline analysis)
  - `iasl -p` to reassemble into `rog-dsdt.aml`
  - Place output in `hosts/rog/acpi/rog-dsdt.aml`

- [ ] **3.3** Add import of `../../modules/hardware/rog-dsdt-override.nix` to `hosts/rog/default.nix` imports list (around line 28, after `rog-poweroff-workaround.nix`)

- [ ] **3.4** Set `hardware.rog.dsdtOverride.enable = true;` in `hosts/rog/default.nix` (near line 75, alongside other hardware options)

- [ ] **3.5** Run `format-nix && nix flake check --no-build` to validate

**Note**: The actual DSDT dump, disassembly, patching, and reassembly is an OFFLINE manual step done on rog hardware. This phase only creates the module structure and import wiring. The `.aml` file is generated later by the user.

**User test gate**: Deploy to rog (will need a valid `rog-dsdt.aml` to actually apply the override), verify dmesg shows DSDT override loaded, test shutdown. If hangs stop, DONE. If not, proceed to Phase 4.

---

## Phase 4: Slice D — Add Direct Port Poweroff

**Goal**: Replace ACPI call with direct port I/O poweroff. Wire C binary into hook. Toggle mode. Test. DONE.

### Tasks

- [ ] **4.1** Extend `modules/hardware/rog-poweroff-workaround.nix`:
  - Add option `hardware.rog.poweroffWorkaround.mode` with type `lib.types.enum ["acpi" "direct"]`, default `"acpi"`
  - Keep existing `enable` option unchanged
  - When `mode = "acpi"`: current behavior (rmmod + acpi_call + _SI._SST)
  - When `mode = "direct"`: skip rmmod and acpi_call, run the direct-poweroff binary instead
  - Update breadcrumb content: "direct-poweroff" when mode is direct, "rog-poweroff hook ran" when acpi
  - Add the direct-poweroff binary to `storePaths` when mode is direct (alongside kmod which stays for acpi fallback)

- [ ] **4.2** Create `pkgs/direct-poweroff/default.nix` (or inline in the module):
  - Small C program (~40 lines) that:
    - Calls `iopl(3)` to gain I/O port access
    - Writes `outw(0x2000, 0x604)` (GPE enable for power-off on ASUS ROG)
    - Returns 0 on success, non-zero on failure
  - Build via `pkgs.stdenv.mkDerivation` with `dontUnpack = true`
  - Static binary, no dependencies beyond libc
  - Output binary name: `direct-poweroff`

- [ ] **4.3** In `hosts/rog/default.nix`, set `hardware.rog.poweroffWorkaround.mode = "direct";`

- [ ] **4.4** Run `format-nix && nix flake check --no-build` to validate

**User test gate**: Deploy to rog, test shutdown. Verify machine powers off via port I/O. Verify diagnostic capture (`shutdown-debug.nix`) still works. DONE.

---

## Cross-Slice Invariants (must hold at every slice)

1. `nix flake check --no-build` exits 0
2. `format-nix` produces no diff
3. Diagnostic capture (`shutdown-debug.nix`) remains functional
4. Breadcrumb file (`/run/shutdown-hook-ran`) is written at shutdown
5. No other hosts are affected (rog-only changes)
6. All shutdown hook commands remain non-blocking (`|| true`)
